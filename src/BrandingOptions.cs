namespace CiamLabApp;

/// <summary>
/// Branding values surfaced in the UI. Bound from the "Branding" section of
/// appsettings.json so the demo can be re-skinned without recompiling.
/// </summary>
public class BrandingOptions
{
    /// <summary>First word of the brand, e.g. "Patitos".</summary>
    public string Name { get; set; } = "Patitos";

    /// <summary>Suffix shown in accent color, e.g. "Corp".</summary>
    public string Suffix { get; set; } = "Corp";

    /// <summary>Short tagline for the home hero.</summary>
    public string Tagline { get; set; } = "Banca digital con personalidad.";

    /// <summary>Footer description.</summary>
    public string Description { get; set; } = "Plataforma demo construida sobre Microsoft Entra External ID.";

    /// <summary>Support / contact line.</summary>
    public string SupportLine { get; set; } = "Construido con autenticación moderna.";

    /// <summary>Convenience: full brand label (Name + Suffix).</summary>
    public string FullName => $"{Name} {Suffix}".Trim();
}
