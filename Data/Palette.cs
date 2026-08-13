namespace Mammod.Data;

/// <summary>
/// One colour per trip, so two trucks out on the same day are two lines a
/// planner can follow apart — that is the whole job of the colour, and it fails
/// the moment two runs share one.
///
/// The server hands these out rather than the client: two clients creating a
/// manifest at the same moment would otherwise pick the same colour.
/// </summary>
public static class Palette
{
    public static readonly string[] RouteColours =
    [
        "#152a4a", // navy — theme primary
        "#e8791c", // orange — theme accent
        "#0f766e", // teal
        "#b91c1c", // brick
        "#6d28d9", // violet
        "#0369a1", // steel blue
        "#a16207", // bronze
        "#be185d", // magenta
    ];

    /// <summary>
    /// Wraps, so numbering trips 0..n never lands past the end of the palette and
    /// draws a line with no colour.
    /// </summary>
    public static string RouteColour(int index) =>
        RouteColours[Math.Abs(index) % RouteColours.Length];
}
