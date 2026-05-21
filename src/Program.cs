using AspNet.Security.OAuth.Apple;
using AspNet.Security.OAuth.Twitter;
using AspNet.Security.OAuth.Yahoo;
using CiamLabApp;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorPages();
builder.Services.AddHttpContextAccessor();
builder.Services.Configure<BrandingOptions>(builder.Configuration.GetSection("Branding"));

// === Auth: cookie principal + multiple external schemes ===
var authBuilder = builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    })
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
    });

bool Has(IConfigurationSection s) =>
    !string.IsNullOrWhiteSpace(s["ClientId"]) && !string.IsNullOrWhiteSpace(s["ClientSecret"]);

var cfg = builder.Configuration;

var msSection = cfg.GetSection("Auth:Microsoft");
if (Has(msSection))
{
    authBuilder.AddMicrosoftAccount("Microsoft", o =>
    {
        o.ClientId = msSection["ClientId"]!;
        o.ClientSecret = msSection["ClientSecret"]!;
        o.SaveTokens = true;
        o.CallbackPath = "/signin-microsoft";
    });
}

var googleSection = cfg.GetSection("Auth:Google");
if (Has(googleSection))
{
    authBuilder.AddGoogle("Google", o =>
    {
        o.ClientId = googleSection["ClientId"]!;
        o.ClientSecret = googleSection["ClientSecret"]!;
        o.SaveTokens = true;
        o.CallbackPath = "/signin-google";
    });
}

var fbSection = cfg.GetSection("Auth:Facebook");
if (Has(fbSection))
{
    authBuilder.AddFacebook("Facebook", o =>
    {
        o.AppId = fbSection["ClientId"]!;
        o.AppSecret = fbSection["ClientSecret"]!;
        o.SaveTokens = true;
        o.CallbackPath = "/signin-facebook";
    });
}

var twitterSection = cfg.GetSection("Auth:Twitter");
if (Has(twitterSection))
{
    authBuilder.AddTwitter("Twitter", o =>
    {
        o.ClientId = twitterSection["ClientId"]!;
        o.ClientSecret = twitterSection["ClientSecret"]!;
        o.SaveTokens = true;
        o.CallbackPath = "/signin-twitter";
    });
}

var yahooSection = cfg.GetSection("Auth:Yahoo");
if (Has(yahooSection))
{
    authBuilder.AddYahoo("Yahoo", o =>
    {
        o.ClientId = yahooSection["ClientId"]!;
        o.ClientSecret = yahooSection["ClientSecret"]!;
        o.SaveTokens = true;
        o.CallbackPath = "/signin-yahoo";
    });
}

var appleSection = cfg.GetSection("Auth:Apple");
if (!string.IsNullOrWhiteSpace(appleSection["ClientId"])
    && !string.IsNullOrWhiteSpace(appleSection["TeamId"])
    && !string.IsNullOrWhiteSpace(appleSection["KeyId"])
    && !string.IsNullOrWhiteSpace(appleSection["PrivateKey"]))
{
    authBuilder.AddApple("Apple", o =>
    {
        o.ClientId = appleSection["ClientId"]!;
        o.TeamId = appleSection["TeamId"]!;
        o.KeyId = appleSection["KeyId"]!;
        o.PrivateKey = (_, _) => Task.FromResult<ReadOnlyMemory<char>>(appleSection["PrivateKey"]!.ToCharArray());
        o.SaveTokens = true;
        o.CallbackPath = "/signin-apple";
    });
}

builder.Services.AddAuthorization();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// Bridge EasyAuth (App Service authentication) -> ClaimsPrincipal so the rest of
// the app (Razor Pages, [Authorize], User.Identity.IsAuthenticated) sees the user
// signed in via Entra External ID (federated with Google, Email/OTP, etc.).
app.Use(async (ctx, next) =>
{
    if (ctx.User?.Identity?.IsAuthenticated != true)
    {
        var header = ctx.Request.Headers["X-MS-CLIENT-PRINCIPAL"].FirstOrDefault();
        if (!string.IsNullOrEmpty(header))
        {
            try
            {
                var json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(header));
                using var doc = System.Text.Json.JsonDocument.Parse(json);
                var root = doc.RootElement;
                var authTyp = root.TryGetProperty("auth_typ", out var at) ? at.GetString() ?? "EasyAuth" : "EasyAuth";
                var nameTyp = root.TryGetProperty("name_typ", out var nt) ? nt.GetString() ?? ClaimTypes.Name : ClaimTypes.Name;
                var roleTyp = root.TryGetProperty("role_typ", out var rt) ? rt.GetString() ?? ClaimTypes.Role : ClaimTypes.Role;
                var claims = new List<Claim>();
                if (root.TryGetProperty("claims", out var arr) && arr.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    foreach (var c in arr.EnumerateArray())
                    {
                        var t = c.TryGetProperty("typ", out var tp) ? tp.GetString() : null;
                        var v = c.TryGetProperty("val", out var vp) ? vp.GetString() : null;
                        if (!string.IsNullOrEmpty(t) && v is not null) claims.Add(new Claim(t, v));
                    }
                }
                var identity = new ClaimsIdentity(claims, authTyp, nameTyp, roleTyp);
                ctx.User = new ClaimsPrincipal(identity);
            }
            catch { /* ignore malformed header */ }
        }
    }

    var schemeProvider = ctx.RequestServices.GetRequiredService<IAuthenticationSchemeProvider>();
    var schemes = await schemeProvider.GetAllSchemesAsync();
    var external = schemes
        .Where(s => s.Name is "Microsoft" or "Google" or "Facebook" or "Twitter" or "Yahoo" or "Apple")
        .Select(s => s.Name)
        .ToHashSet();
    ctx.Items["ConfiguredProviders"] = external;

    if (ctx.User?.Identity?.IsAuthenticated == true)
    {
        var u = new SiteUser
        {
            DisplayName = ctx.User.FindFirst(ClaimTypes.Name)?.Value
                          ?? ctx.User.FindFirst("name")?.Value
                          ?? ctx.User.FindFirst("preferred_username")?.Value
                          ?? ctx.User.Identity.Name ?? "Usuario",
            Name = ctx.User.Identity.Name ?? "",
            Email = ctx.User.FindFirst(ClaimTypes.Email)?.Value
                    ?? ctx.User.FindFirst("email")?.Value
                    ?? ctx.User.FindFirst("preferred_username")?.Value ?? "",
            IdentityProvider = ctx.User.FindFirst("idp")?.Value
                               ?? ctx.User.Claims.FirstOrDefault(c => c.Type.EndsWith("identityprovider"))?.Value
                               ?? ctx.User.Identities.FirstOrDefault()?.AuthenticationType ?? "",
            Claims = ctx.User.Claims.Select(c => new SiteClaim { Type = c.Type, Value = c.Value }).ToList()
        };
        ctx.Items["user"] = u;
    }
    await next();
});

app.MapRazorPages();

// Minimal API endpoint for the React shell to read the authenticated user
app.MapGet("/api/me", (HttpContext ctx) =>
{
    if (ctx.Items["user"] is SiteUser u)
    {
        return Results.Json(new
        {
            authenticated = true,
            displayName = u.DisplayName,
            email = u.Email,
            idp = u.IdentityProvider,
            initials = string.Join("", (u.DisplayName ?? "")
                .Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Take(2)
                .Select(p => char.ToUpper(p[0])))
        });
    }
    return Results.Json(new { authenticated = false });
});

app.Run();

namespace CiamLabApp
{
    public class SiteUser
    {
        public string DisplayName { get; set; } = "";
        public string Name { get; set; } = "";
        public string Email { get; set; } = "";
        public string IdentityProvider { get; set; } = "";
        public List<SiteClaim> Claims { get; set; } = new();
    }
    public class SiteClaim
    {
        public string Type { get; set; } = "";
        public string Value { get; set; } = "";
    }
}
