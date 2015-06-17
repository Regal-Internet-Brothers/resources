Strict

Public

' Imports:
Import mojo2util.cache

' Interfaces:

' This acts as the standard call-back interface for 'Texture' objects.
Interface TextureRecipient
	' Methods:
	
	' Call-backs:
	
	' Basically, when a texture is loaded, this is called.
	Method OnTextureLoaded:Void(Path:String, T:Texture)
End

' Classes:
#Rem
	DESCRIPTION:
		* This provides basic 'Texture' caching, for details, please view the 'ResourceCache' class's documentation.
	NOTES:
		* This class requires that shared textures may not have different flags.
		The rule is, the flags used to perform a real loading operation last will affect the cached 'Texture'.
		
		* You may not reload a texture safely, however, this may be done using 'ForceReload'.
#End
Class TextureCache Extends ResourceCache<Texture> Final
	' Global variable(s):
	Global DefaultFlags:= (Texture.Filter|Texture.Mipmap|Texture.ClampST)
	
	' Change at your own risk; please view the documentation's notes regarding texture-format.
	Global DefaultFormat:= 4
	
	' Methods:
	
	' This method is considered "unsafe", as it will destroy any formal object ties for new objects.
	' The original texture-data will be released normally. Texture-data will only stay valid if something else has retained it.
	Method ForceReload:Void()
		' Enumerate every texture-node:
		For Local TN:= Eachin Cache
			' Get the current texture.
			Local T:= TN.Value
			
			' Load data from the texture.
			Local Flags:= T.Flags
			Local Format:= T.Format
			
			' Release our tie to this texture.
			T.Release()
			
			Local NewResource:= Texture.Load(TN.Key, Format, Flags)
			
			NewResource.Retain()
			
			Cache.Update(TN.Key, NewResource)
		Next
		
		Return
	End
	
	Method Load:Void(Recipient:TextureRecipient, Path:String, Format:Int=DefaultFormat, Flags:Int=DefaultFlags)
		Recipient.OnTextureLoaded(Path, Load(Path, Format, Flags))
		
		Return
	End
	
	Method Load:Texture(Path:String, Format:Int=DefaultFormat, Flags:Int=DefaultFlags)
		Local T:= Cache.Get(Path)
		
		If (T <> Null) Then
			Return T
		Endif
		
		T = Texture.Load(Path, Format, Flags)
		
		T.Retain()
		
		Cache.Set(Path, T)
		
		Return T
	End
End