using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BNFondosLab.Pages;

public class DocumentosModel : PageModel
{
    public record Doc(string Title, string Meta, string Url);

    public List<Doc> Docs { get; } = new()
    {
        new("Prospecto BN Mercado de Dinero ¢", "Fondo financiero en colones · PDF · v.2026-04", "https://48395929.fs1.hubspotusercontent-na1.net/hubfs/48395929/BN_ETF500_ETF_BITCOIN.pdf"),
        new("Prospecto BN Mercado de Dinero $", "Fondo financiero en dólares · PDF · v.2026-04", "https://48395929.fs1.hubspotusercontent-na1.net/hubfs/48395929/BN_ETF500_ETF_BITCOIN.pdf"),
        new("BN ETF 500 — Hoja informativa", "Fondo no diversificado · PDF · 2026", "https://48395929.fs1.hubspotusercontent-na1.net/hubfs/48395929/BN_ETF500_ETF_BITCOIN.pdf"),
        new("BN ETF Bitcoin — Hoja informativa", "Fondo no diversificado · PDF · 2026", "https://48395929.fs1.hubspotusercontent-na1.net/hubfs/48395929/BN_ETF500_ETF_BITCOIN.pdf"),
        new("Reporte mensual — Marzo 2026", "Rendimientos y composición de portafolio", "https://48395929.fs1.hubspotusercontent-na1.net/hubfs/48395929/BN_ETF500_ETF_BITCOIN.pdf"),
        new("Hechos relevantes Q1-2026", "Comunicados oficiales", "https://48395929.fs1.hubspotusercontent-na1.net/hubfs/48395929/BN_ETF500_ETF_BITCOIN.pdf"),
    };

    public void OnGet() { }
}
