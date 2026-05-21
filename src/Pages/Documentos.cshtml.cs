using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CiamLabApp.Pages;

public class DocumentosModel : PageModel
{
    public record Doc(string Title, string Meta, string Url);

    public List<Doc> Docs { get; } = new()
    {
        new("Prospecto Patitos Cash ¢", "Fondo de liquidez en colones · PDF · v.2026-04", "#"),
        new("Prospecto Patitos Cash $", "Fondo de liquidez en dólares · PDF · v.2026-04", "#"),
        new("Patitos ETF 500 — Hoja informativa", "Fondo de inversión global · PDF · 2026", "#"),
        new("Patitos ETF Bitcoin — Hoja informativa", "Fondo de inversión cripto · PDF · 2026", "#"),
        new("Reporte mensual — Marzo 2026", "Rendimientos y composición de portafolio", "#"),
        new("Hechos relevantes Q1-2026", "Comunicados oficiales", "#"),
    };

    public void OnGet() { }
}
