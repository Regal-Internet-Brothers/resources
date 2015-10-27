Strict

Public

' Preprocessor related:
#RESOURCES_RESOURCEMANAGER_PREFER_ATLASES = True

' Imports:
Import resources ' regal.resources

Import assetentrymanager

' Classes:

' This acts as a standard "hub" class for dealing with resources / loaded assets.
Class ResourceManager
	' Constructor(s):
	Method New()
		GenerateSystems()
	End
	
	#If Not RESOURCES_RESOURCEMANAGER_PREFER_ATLASES
		Method New(Images:ImageManager)
	#Else
		Method New(Images:AtlasImageManager)
	#End
			Self.Images = Images
		End
	
	#If RESOURCES_SOUND_IMPLEMENTED
		Method New(Sounds:SoundManager)
			Self.Sounds = Sounds
		End
		
		#If Not RESOURCES_RESOURCEMANAGER_PREFER_ATLASES
			Method New(Images:ImageManager, Sounds:SoundManager)
		#Else
			Method New(Images:AtlasImageManager, Sounds:SoundManager)
		#End
				Self.Images = Images
				Self.Sounds = Sounds
			End
	#End
	
	Method GenerateSystems:Void()
		#If Not RESOURCES_RESOURCEMANAGER_PREFER_ATLASES
			Self.Images = New ImageManager()
		#Else
			Self.Images = New AtlasImageManager()
		#End
		
		#If RESOURCES_SOUND_IMPLEMENTED
			Self.Sounds = New SoundManager()
		#End
		
		Return
	End
	
	' Methods:
	Method Free:ResourceManager()
		Self.Images.FreeAssets()
		Self.Sounds.FreeAssets()
		
		Self.Images = Null
		
		#If RESOURCES_SOUND_IMPLEMENTED
			Self.Sounds = Null
		#End
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	' Fields:
	#If Not RESOURCES_RESOURCEMANAGER_PREFER_ATLASES
		Field Images:ImageManager
	#Else
		Field Images:AtlasImageManager
	#End
	
	#If RESOURCES_SOUND_IMPLEMENTED
		Field Sounds:SoundManager
	#End
End