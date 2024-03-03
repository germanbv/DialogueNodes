using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

[GlobalClass]
[Tool]
public partial class BBCodeWait : RichTextEffect
{	
	[Signal] 
    public delegate void WaitFinishedEventHandler();

	[Signal] 
    public delegate void CharDisplayedEventHandler();
	
	public bool Skip = false;
	public float Speed = 50.0f;
	public float PauseValue = 0.45f;
	//syntax: [wait][/wait]
	private readonly string bbcode = "wait";

	private Dictionary<int, float> pausesDict;
	private Dictionary<int, float> speedDict;
	private int lastIndex;
	private int nextChar;

	private float halfPause;
	private uint pauseChar;
	private uint[] halfPauseChars;

	private float currentSpeed;
	private float currentPause;
	private double lastFrameTime;
	private double elapsedTime;
	

	private void initText(CharFXTransform charFX) 
	{	
		initDictionary("pause", charFX, ref pausesDict);
		initDictionary("speed", charFX, ref speedDict);
		initPauseChars(charFX);

		nextChar = 0;
		lastIndex = 0;
		currentPause = 0;
		currentSpeed = Speed;
		elapsedTime = 0;
		lastFrameTime = 0;
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
	}

	private uint charToGlyphIndex(Rid font, uint c)
    {	
		return Convert.ToUInt32(TextServerManager.GetPrimaryInterface().FontGetGlyphIndex(font, 1, c, 0));
    }

	public override bool _ProcessCustomFX(CharFXTransform charFX)
    {	
		if (charFX.ElapsedTime == 0 && charFX.RelativeIndex == 0) 
		{
			initText(charFX);
		}

		double delta = charFX.ElapsedTime - lastFrameTime;
        lastFrameTime = charFX.ElapsedTime;
		elapsedTime += delta;
		lastIndex = Math.Max(lastIndex, charFX.RelativeIndex);

		if (charFX.RelativeIndex >= nextChar) 
		{
			int absoluteIndex = charFX.RelativeIndex;
		
			if (elapsedTime > ((float)absoluteIndex / currentSpeed) + currentPause || Skip)
			{	
				if (pauseChar == charFX.GlyphIndex) 
				{	
					currentPause += PauseValue;
				}
				else if (halfPauseChars.Contains(charFX.GlyphIndex)) 
				{
					currentPause += halfPause;
				}

				charFX.Visible = true;
				nextChar++;

				if (!Skip) 
				{
					EmitSignal("CharDisplayed");
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
			charFX.Visible = true;
		}

		return true;
	}
}