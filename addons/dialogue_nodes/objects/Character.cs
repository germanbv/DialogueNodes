using Godot;

public partial class Character : Resource
{
	[Export] public string Name { get; set; } = "";
    [Export] public Texture2D Image { get; set; }
    [Export] public Color Color { get; set; } = Color.Color8(255, 255, 255);
}
