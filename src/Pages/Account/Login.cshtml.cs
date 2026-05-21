using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BNFondosLab.Pages.Account;

public class LoginModel : PageModel
{
    public string ReturnUrl { get; set; } = "/";
    public IReadOnlyCollection<string> Configured { get; private set; } = Array.Empty<string>();
    public string? Error { get; set; }

    public void OnGet(string? returnUrl = null, string? error = null)
    {
        ReturnUrl = string.IsNullOrEmpty(returnUrl) ? "/Documentos" : returnUrl;
        Error = error;
        Configured = HttpContext.Items["ConfiguredProviders"] as HashSet<string> ?? new HashSet<string>();
    }

    public IActionResult OnPostExternal(string provider, string? returnUrl = null)
    {
        var redirect = string.IsNullOrEmpty(returnUrl) ? "/Documentos" : returnUrl;
        var configured = HttpContext.Items["ConfiguredProviders"] as HashSet<string> ?? new HashSet<string>();
        if (!configured.Contains(provider))
        {
            return RedirectToPage("Login", new { returnUrl = redirect, error = $"El proveedor '{provider}' no está configurado todavía. Revise las App Settings Auth:{provider}:ClientId y Auth:{provider}:ClientSecret." });
        }
        var props = new AuthenticationProperties
        {
            RedirectUri = Url.Page("ExternalCallback", new { returnUrl = redirect }),
            Items = { ["provider"] = provider, ["returnUrl"] = redirect }
        };
        return Challenge(props, provider);
    }
}
