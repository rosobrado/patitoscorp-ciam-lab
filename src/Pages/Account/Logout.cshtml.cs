using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BNFondosLab.Pages.Account;

public class LogoutModel : PageModel
{
    public Task<IActionResult> OnPostAsync() => Task.FromResult<IActionResult>(Redirect("/.auth/logout?post_logout_redirect_uri=/"));
    public Task<IActionResult> OnGetAsync() => Task.FromResult<IActionResult>(Redirect("/.auth/logout?post_logout_redirect_uri=/"));
}
