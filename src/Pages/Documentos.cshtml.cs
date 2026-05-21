using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CiamLabApp.Pages;

public class DocumentosModel : PageModel
{
    public record Account(string Name, string Number, string Currency, decimal Balance, decimal AvailableBalance);
    public record Transaction(string Date, string Description, string Category, decimal Amount, string Currency);

    public bool Seeded { get; private set; }
    public List<Account> Accounts { get; private set; } = new();
    public List<Transaction> Transactions { get; private set; } = new();

    private static readonly List<Account> _seededAccounts = new()
    {
        new("Cuenta Pato Corriente",     "CR21-0151-0000-1234-5678", "CRC", 4_312_050.42m, 4_312_050.42m),
        new("Cuenta Pato USD",           "CR21-0151-0000-9876-5432", "USD",     7_215.40m,     7_215.40m),
        new("Patitos Save \u00b7 Vacaciones", "CR21-0151-0000-1111-2222", "CRC",   850_000.00m, 0m),
    };

    private static readonly List<Transaction> _seededTx = new()
    {
        new("2026-05-19", "Transferencia SINPE \u2014 Mariana R.",   "Transferencia",  -45_000m, "CRC"),
        new("2026-05-19", "Patitos Save \u2014 Aporte programado",   "Ahorro",         -25_000m, "CRC"),
        new("2026-05-18", "Pago de salario \u2014 Patitos Corp",     "Ingreso",      1_250_000m, "CRC"),
        new("2026-05-17", "Compra \u2014 Caf\u00e9 del Parque",      "Restaurantes",     -3_400m, "CRC"),
        new("2026-05-17", "Compra \u2014 Spotify Premium",           "Suscripciones",    -2_950m, "CRC"),
        new("2026-05-16", "Retiro cajero \u2014 ATH Bulevar",        "Efectivo",       -50_000m, "CRC"),
        new("2026-05-15", "Devoluci\u00f3n \u2014 Tienda Verde",     "Reembolso",       12_500m, "CRC"),
        new("2026-05-14", "Compra USD \u2014 AWS Cloud",             "Servicios",         -42.18m, "USD"),
    };

    private static readonly Account _emptyAccount =
        new("Cuenta Pato Corriente", "CR21-0151-0000-1234-5678", "CRC", 0m, 0m);

    public IActionResult OnGet(string? seed = null, string? reset = null)
    {
        var isAuth = HttpContext.Items["user"] is CiamLabApp.SiteUser;

        // KYC gate: a real bank always runs you through onboarding once.
        if (isAuth && Request.Cookies["pb_kyc_done"] != "1")
        {
            return Redirect("/Bienvenido?next=/Cuenta");
        }

        var opts = new CookieOptions { Path = "/", IsEssential = true, MaxAge = TimeSpan.FromDays(30) };

        if (seed == "1")
        {
            Response.Cookies.Append("pb_seeded", "1", opts);
            return Redirect("/Cuenta");
        }
        if (reset == "1")
        {
            Response.Cookies.Delete("pb_seeded", new CookieOptions { Path = "/" });
            return Redirect("/Cuenta");
        }

        Seeded = Request.Cookies["pb_seeded"] == "1";
        if (Seeded)
        {
            Accounts = _seededAccounts;
            Transactions = _seededTx;
        }
        else
        {
            Accounts = new List<Account> { _emptyAccount };
            Transactions = new List<Transaction>();
        }
        return Page();
    }
}