using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Security.Claims;

namespace CiamLabApp.Pages.Account;

public class ExternalCallbackModel : PageModel
{
    public async Task<IActionResult> OnGetAsync(string? returnUrl = null)
    {
        var auth = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        if (!auth.Succeeded)
        {
            // The cookie may not be present yet; the OAuth handler signs in the cookie scheme directly.
            // The middleware then has the user. If we got here without auth, send to login.
            return RedirectToPage("Login", new { error = "No fue posible completar la autenticación.", returnUrl });
        }
        return LocalRedirect(string.IsNullOrEmpty(returnUrl) ? "/Documentos" : returnUrl);
    }
}
