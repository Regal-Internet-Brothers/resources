#Rem
	DESCRIPTION:
		* This module provides classes which alllow you to use shared "texture caches".
	NOTES:
		* This sub-module requires the Mojo2 module.
#End

Strict

Public

' Preprocessor related:
'#If Not RESOURCES_MOJO2
	'#Error "Please enable Mojo 2 functionality via 'RESOURCES_MOJO2'."
'#End

' Imports (Internal):
'Import assetmanager

' Imports (External):
Import mojo2.graphics

Import monkey.map

' Classes:

#Rem
	DESCRIPTION:
		* This allows you to cache resources, reducing overhead and memory consumption.
	NOTES:
		* The 'ResourceType' argument must be a valid 'RefCounted' type, as described by Mojo 2.
#End

Class ResourceCache<ResourceType> Abstract ' Extends AssetManager<Texture>
	' Constructor(s):
	Method New()
		Cache = New StringMap<ResourceType>()
	End
	
	' Destructor(s):
	Method Free:Void()
		ReleaseResources(True)
		
		Return
	End
	
	' This command destroys the internally cached resources.
	' Use the 'ClearReferences' argument at your own risk.
	' If unsure, please specify nothing.
	Method ReleaseResources:Void(ClearReferences:Bool=True)
		For Local T:= Eachin Cache.Values()
			T.Release()
		Next
		
		If (ClearReferences) Then
			Cache.Clear()
		Endif
		
		Return
	End
	
	' Methods:
	
	' This will manually release ownership of 'T'.
	' You should only use this if you intend to
	' completely remove 'T' from this cache.
	' The return value dictates whether the operation was successful.
	Method Release:Bool(R:ResourceType)
		For Local RN:= Eachin Cache
			If (RN.Value = R) Then
				R.Release()
				
				Cache.Remove(RN.Key)
				
				Return True
			Endif
		Next
		
		' Return the default response.
		Return False
	End

	' This will check for a 'ResourceType' with the path specified, then release it from this cache.
	' The rules of the primary overload apply here; use this at your own risk.
	Method Release:Bool(Path:String)
		Local R:= Cache.Get(Path)
		
		If (R <> Null) Then
			R.Release()
			
			Cache.Remove(Path)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	Field Cache:StringMap<ResourceType>
	
	Public
End