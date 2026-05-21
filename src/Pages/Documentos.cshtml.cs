using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CiamLabApp.Pages;

public class DocumentosModel : PageModel
{
    public record Account(string Name, string Number, string Currency, decimal Balance, decimal AvailableBalance);
    public record Transaction(string Date, string Description, string Category, decimal Amount, string Currency);

    public List<Account> Accounts { get; } = new()
    {
        new("Cuenta Pato Corriente",  "CR21-0151-0000-1234-5678", "CRC", 4_312_050.42m, 4_312_050.42m),
        new("Cuenta Pato USD",        "CR21-0151-0000-9876-5432", "USD", 7_215.40m,     7_215.40m),
        new("Patitos Save · Vacaciones", "CR21-0151-0000-1111-2222", "CRC", 850_000.00m, 0m),
    };

    public List<Transaction> Transactions { get; } = new()
    {
        new("2026-05-19", "Transferencia SINPE — Mariana R.",        "Transferencia",  -45_000m, "CRC"),
        new("2026-05-19", "Patitos Save — Aporte programado",        "Ahorro",         -25_000m, "CRC"),
        new("2026-05-18", "Pago de salario — Patitos Corp",          "Ingreso",      1_250_000m, "CRC"),
        new("2026-05-17", "Compra — Café del Parque",                "Restaurantes",     -3_400m, "CRC"),
        new("2026-05-17", "Compra — Spotify Premium",                "Suscripciones",    -2_950m, "CRC"),
        new("2026-05-16", "Retiro cajero — ATH Bulevar",              "Efectivo",       -50_000m, "CRC"),
        new("2026-05-15", "Devolución — Tienda Verde",                "Reembolso",       12_500m, "CRC"),
        new("2026-05-14", "Compra USD — AWS Cloud",                  "Servicios",         -42.18m, "USD"),
    };

    public void OnGet() { }
}
