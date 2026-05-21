using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CiamLabApp.Pages;

public class BienvenidoModel : PageModel
{
    public string Next { get; private set; } = "/Cuenta";

    public IActionResult OnGet(string? next = null)
    {
        var isAuth = HttpContext.Items["user"] is CiamLabApp.SiteUser;
        if (!isAuth) return Redirect("/Account/Login?returnUrl=/Bienvenido");

        var dest = SanitizeNext(next);
        if (Request.Cookies["pb_kyc_done"] == "1") return Redirect(dest);

        Next = dest;
        return Page();
    }

    public IActionResult OnPost(string? next = null)
    {
        var isAuth = HttpContext.Items["user"] is CiamLabApp.SiteUser;
        if (!isAuth) return Redirect("/Account/Login?returnUrl=/Bienvenido");

        Response.Cookies.Append("pb_kyc_done", "1", new CookieOptions
        {
            Path = "/",
            IsEssential = true,
            MaxAge = TimeSpan.FromDays(365)
        });
        return Redirect(SanitizeNext(next));
    }

    private static string SanitizeNext(string? next)
    {
        if (string.IsNullOrWhiteSpace(next)) return "/Cuenta";
        if (!next.StartsWith("/") || next.StartsWith("//")) return "/Cuenta";
        return next;
    }
}