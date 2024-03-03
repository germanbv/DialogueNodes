using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

[GlobalClass]
[Tool]
public partial class BBCodeConsole : RichTextEffect
{	
	[Signal] 
    public delegate void WaitFinishedEventHandler();

	[Signal] 
    public delegate void CharDisplayedEventHandler(int charIndex);
	
	public bool Skip = false;
	public float Speed = 50.0f;
	public float PauseValue = 0.45f;

	//syntax: [wait][/wait]
	private readonly string bbcode = "wait";
	private readonly uint cursor = "█"[0];
	private readonly uint space = " "[0];

	private int i = 0;
	private bool on = false;
	
	private Dictionary<int, float> pausesDict;
	private Dictionary<int, float> speedDict;

	private int lastIndex;
	private int lastProcessedCharIndex;
	private HashSet<int> processedChar;
	private float halfPause;
	private uint pauseChar;
	private uint[] halfPauseChars;
	private float currentSpeed;
	private float currentPause;
	private uint cursorAsGlyphIndex;
	private uint spaceAsGlyphIndex;
	private double lastFrameTime = 0.0f;
	private double elapsedTime = 0.0f;


	private void initText(CharFXTransform charFX) 
	{	
		processedChar = new HashSet<int>();

		cursorAsGlyphIndex = charToGlyphIndex(charFX.Font, cursor); 
		spaceAsGlyphIndex = charToGlyphIndex(charFX.Font, space);

		initDictionary("pause", charFX, ref pausesDict);
		initDictionary("speed", charFX, ref speedDict);
		initPauseChars(charFX);

		i = 0;
		on = false;
		lastIndex = 0;
		lastProcessedCharIndex = 0;
		lastFrameTime = 0;
		currentPause = 0;
		currentSpeed = Speed;
		elapsedTime = 0;
		halfPause = PauseValue / 2;

		if (pausesDict != null && pausesDict.ContainsKey(0)) 
		{
			currentPause = pausesDict[0];
		}
		else if (charFX.GlyphIndex == pauseChar) 
		{	
			currentPause += PauseValue;
		}
	}

	private void initDictionary(string code, CharFXTransform charFX, ref Dictionary<int, float> dictionary) 
	{
		bool hasPausePositions = charFX.Env.TryGetValue($"{code}Positions", out Variant pauseVariant);
		bool hasPauseValues = charFX.Env.TryGetValue($"{code}Values", out Variant pauseValuesVariant);

		dictionary = null;

		if (hasPausePositions && hasPauseValues) 
		{
			int[] positions = null;
			float[] values = null;

			if (pauseVariant.VariantType == Variant.Type.Float && pauseValuesVariant.VariantType == Variant.Type.Float) 
			{
				positions = new int[]{pauseVariant.AsInt32()};
				values = new float[]{(float)pauseValuesVariant};
			}
			else if (pauseVariant.VariantType == Variant.Type.Array && pauseValuesVariant.VariantType == Variant.Type.Array) 
			{
				positions = pauseVariant.AsInt32Array();
				values = pauseValuesVariant.AsFloat32Array();
			}

			if (positions != null && values != null && positions.Length == values.Length) 
			{
				dictionary = new Dictionary<int, float>();

				for (int i = 0; i < positions.Length; i++) 
				{
					dictionary.Add(positions[i], values[i]);
				}
			}
		}
		else 
		{
			dictionary = null;
		}
	}

	private void initPauseChars(CharFXTransform charFX) 
	{
		pauseChar = charToGlyphIndex(charFX.Font, "."[0]);

		halfPauseChars = new uint[] 
		{
			charToGlyphIndex(charFX.Font, ","[0]),
			charToGlyphIndex(charFX.Font, ";"[0]),
			charToGlyphIndex(charFX.Font, ":"[0]),
		};
	}

	private uint charToGlyphIndex(Rid font, uint c)
    {	
		return Convert.ToUInt32(TextServerManager.GetPrimaryInterface().FontGetGlyphIndex(font, 1, c, 0));
    }

	public override bool _ProcessCustomFX(CharFXTransform charFX)
    {	
		if (charFX.ElapsedTime == 0 && charFX.RelativeIndex == 0) initText(charFX);

		double delta = charFX.ElapsedTime - lastFrameTime;
        lastFrameTime = charFX.ElapsedTime;
		elapsedTime += delta;
		lastIndex = Math.Max(lastIndex, charFX.RelativeIndex);

		if (!processedChar.Contains(charFX.RelativeIndex))
		{	
			int absoluteIndex = charFX.RelativeIndex;
			
			if (elapsedTime > ((float)absoluteIndex / currentSpeed) + currentPause || Skip) 
			{	
				if (pauseChar == charFX.GlyphIndex && charFX.RelativeIndex != lastIndex-1) 
				{	
					currentPause += PauseValue;
				}
				else if (halfPauseChars.Contains(charFX.GlyphIndex)) 
				{
					currentPause += halfPause;
				}

				charFX.GlyphIndex = charFX.GlyphIndex != spaceAsGlyphIndex ? cursorAsGlyphIndex : charFX.GlyphIndex;

				charFX.Visible = true;
				processedChar.Add(charFX.RelativeIndex);
				lastProcessedCharIndex = absoluteIndex;

				if (!Skip) 
				{
					EmitSignal("CharDisplayed", absoluteIndex);
				}
				
				if (absoluteIndex >= lastIndex) 
				{
					EmitSignal("WaitFinished");
				}
				
				if (pausesDict != null && pausesDict.ContainsKey(absoluteIndex)) 
				{
					currentPause += pausesDict[absoluteIndex];
				}

				if (speedDict != null && speedDict.ContainsKey(absoluteIndex)) 
				{	
					currentSpeed = speedDict[absoluteIndex];

					if (currentSpeed < 1) 
					{
						currentSpeed = Speed;
					}
					elapsedTime = absoluteIndex / currentSpeed + currentPause;
				}
			}
			else 
			{	
				//character waiting to be processed;
				charFX.Visible = false;
			}
		}
		else 
		{	
			//character already processed
			if (charFX.RelativeIndex == lastProcessedCharIndex) 
			{
				uint cursorAsGlyphIndex = charToGlyphIndex(charFX.Font, cursor);

				if (i % 20 == 0) 
				{	
					on = !on;
				}
				if (on) 
				{	
					charFX.GlyphIndex = cursorAsGlyphIndex;
				}
				i++;	
			}

			charFX.Visible = true;
		}

		return true;
	}
}
