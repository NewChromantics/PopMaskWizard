using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class ScanlineMasker : MonoBehaviour {

	public Texture			SourceTexture;
	public Material			ScanlineFilter;

	public ComputeShader	MaskerShader;
	public string			MaskerKernel = "WriteMask";
	public RenderTexture	MaskedTexture;
	public bool				Dirty = true;

	[Range(0,1)]
	public float			OriginX = 0.5f;
	[Range(0,1)]
	public float			OriginY = 0.5f;
	[Range(0,10)]
	public int				SearchRows = 10;

	void Update () {
	
		if (!Dirty)
			return;

		//	make filtered source
		var ScanlineTexture = new RenderTexture( SourceTexture.width, SourceTexture.height, 0 );
		Graphics.Blit( SourceTexture, ScanlineTexture, ScanlineFilter );

		//	copy original into mask
		Graphics.Blit( SourceTexture, MaskedTexture );

		var Kernel = MaskerShader.FindKernel (MaskerKernel);
		MaskerShader.SetTexture (Kernel, "ScanlineTexture", ScanlineTexture);
		MaskerShader.SetTexture(Kernel, "MaskTexture", MaskedTexture);
		MaskerShader.SetVector( "Origin", new Vector4( SourceTexture.width*OriginX, SourceTexture.height*OriginY,0,0 ) );
		MaskerShader.Dispatch (Kernel, 1, SearchRows, 1);

		Dirty = false;
	}
}
