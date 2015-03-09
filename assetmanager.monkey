Strict

Public

' Imports:
' Nothing so far.

' Preprocessor related:
#RESOURCES_ASSETMANAGER_THROW_ERRORS = True
#RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_STACK ' MOJOWRAPPER_CONTAINERTYPE_LIST

#If RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_STACK Or RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_LIST
	#RESOURCES_ASSETMANAGER_STANDARD_CONTAINER = True
#End

' Check for debug-specific rules:
#If CONFIG = "debug"
	#If Not RESOURCES_ASSETMANAGER_THROW_ERRORS
		' This preprocessor variable generally doesn't take
		' priority over 'RESOURCES_ASSETMANAGER_THROW_ERRORS'.
		' That being said, debug-stopping may take place regardless.
		#RESOURCES_ASSETMANAGER_DEBUGSTOP_ON_ERRORS = True
	#End
#End

#If RESOURCES_ASSETMANAGER_DEBUGSTOP_ON_ERRORS
	' This is currently only enabled as a fall-back for debugging functionality.
	#RESOURCES_ASSETMANAGER_DEBUGSTOP_ON_EXCEPTIONS = True
#End

' Aliases:
#If RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_STACK
	Alias AssetContainer = Stack
	Alias AssetEnumerator = monkey.stack.Enumerator
#Else ' #Elseif RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_LIST
	Alias AssetContainer = List
	Alias AssetEnumerator = monkey.list.Enumerator
#End

#If RESOURCES_ASSETMANAGER_STANDARD_CONTAINER
	#RESOURCES_ASSETMANAGER_STANDARDENUMERATION = True
#End

' Interfaces:

' This interface is only used for debugging purposes.
Interface AssetManager_DebugInterface
	' Methods:
	' Nothing so far.
	
	' Properties:
	' Nothing so far.
End

' Classes:
Class AssetManager<AssetType> Implements AssetManager_DebugInterface ' Abstract
	' Constructor(s) (Public):
	Method New(CreateContainer:Bool=True)
		' Call the main implementation.
		ConstructManager(CreateContainer)
		
		' Nothing else so far.
	End
	
	Method New(Assets:AssetContainer<AssetType>, CopyData:Bool=True)
		' Call the main implementation.
		ConstructManager(Assets, Not CopyData)
	End
	
	' Calling these constructors on an inheriting object is considered bad practice (Unless otherwise stated).
	' It is up to that particular implementation to decide how this constructor should be used.
	Method ConstructManager:AssetManager<AssetType>(Assets:AssetContainer<AssetType>, CopyData:Bool=True)
		' Check for errors:
		
		' Attempt to construct this object:
		If (ConstructManager(CopyData) = Null) Then
			Return Null
		Endif
		
		' Check how we're dealing with the input:
		If (Not CopyData) Then
			Self.Container = Assets
		Else
			AddAssets(Assets)
		Endif
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	Method ConstructManager:AssetManager<AssetType>(CreateContainer:Bool=True)
		If (CreateContainer) Then
			CreateInternalContainer()
		Endif
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	#Rem
		This command will not create the internal-container, but instead,
		it will return a new instance of the container-type.
		To create the internal container, please use either
		'EnsureContainer' (Recommended), or 'CreateInternalContainer'.
	#End
	
	Method MakeContainer:AssetContainer<AssetType>()
		Return New AssetContainer<AssetType>()
	End
	
	#Rem
		This command will ensure that the internal
		container exists, even if it has to create one.
		
		If your code requires one to exist, but you are
		unsure of its state, please use this command first.
	#End
	
	Method EnsureContainer:AssetContainer<AssetType>()
		' Check if a call-back container exists:
		If (Self.Container = Null) Then
			Return CreateInternalContainer()
		Endif
		
		Return Self.Container
	End
	
	#Rem
		This may be used to create the internal container.
		Please keep in mind that this is not "safe". This will
		force the internal container to be recreated.
		
		To safely create the internal-container without worrying
		about its current state, please use 'EnsureContainer'.
	#End
	
	Method CreateInternalContainer:AssetContainer<AssetType>()
		' Allocate a new container object, then
		' assign the internal-container to it.
		Self.Container = MakeContainer()
		
		' Return the internal-container.
		Return Self.Container
	End
	
	' Destructor(s) (Public):
	
	#Rem
		This method is implementation-defined, and may be overridden as needed.
		
		Reimplementation practices are defined by the initial inheriting class(es),
		and may require "calling up" to their implementation(s). That being said,
		you should only call this with the intention of manually dealing with
		the lingering "entries". Common practice (As followed by this class)
		is to call 'ClearContainer' after calling 'FreeAssets'.
		
		This is generally recommended practice, and should be done to at least some degree.
		The final effects of this method are largely undefined in this class.
	#End
	
	Method FreeAssets:Bool()
		' Return the default response.
		Return True
	End
	
	' The standard implementation of this command is always safe.
	Method ClearContainer:Bool()
		#If RESOURCES_ASSETMANAGER_STANDARD_CONTAINER
			If (Container <> Null) Then
				Container.Clear()
				
				Return True
			Endif
		#Else
			'Error_Unsupported()
		#End
		
		Return False
	End
	
	' Destructor(s) (Private):
	Private
	
	' The 'DestroyData' argument is used to determine if 'FreeAssets' should be called.
	' Like most destructors, inheriting classes are advised to "call up" to this implementation.
	Method FreeManager:AssetManager<AssetType>(DestroyData:Bool=False)
		If (DestroyData) Then
			FreeAssets()
		Endif
		
		ClearContainer()
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	Public
	
	' Methods (Public):
	
	#Rem
		The 'AddAsset' and 'RemoveAsset' commands are considered "unsafe" under certain conditions.
		Some inheriting classes may be against the direct usage of these commands, please take this into account.
		Such implementations are recommended to make private wrappers, inaccessible to the user.
	#End
	
	Method AddAsset:Bool(Asset:AssetType)
		#If RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_STACK
			Container.Push(Asset)
			
			' Tell the user that operations were successful.
			Return True
		#Elseif RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_LIST
			Return (Container.AddLast(I) <> Null)
		#Else
			Error_Unsupported()
			
			Return False
		#End
	End
	
	Method RemoveAsset:Bool(Asset:AssetType)
		#If RESOURCES_ASSETMANAGER_STANDARD_CONTAINER
			' Unfortunately, the return value of this is currently undefined.
			Container.RemoveEach(Asset)
			
			Return True
		#Else
			Error_Unsupported()
			
			Return False
		#End
	End
	
	Method AddAssets:Bool(Assets:AssetManager<AssetType>)
		Return AddAssets(Assets.Container)
	End
	
	Method AddAssets:Bool(Assets:AssetContainer<AssetType>)
		For Local Asset:= Eachin Assets
			AddAsset(Asset)
		Next
		
		' Return the default response.
		Return True
	End
	
	Method Contains:Bool(A:AssetType)
		#If RESOURCES_ASSETMANAGER_STANDARD_CONTAINER
			Return Container.Contains(A)
		#Else
			Error_Unsupported()
			
			Return False
		#End
	End
	
	' Methods (Private):
	Private
	
	Method Error_Unsupported:Void()
		UnsupportedOperation(Self)
		
		Return
	End
	
	Public
	
	' Properties:
	#If RESOURCES_ASSETMANAGER_STANDARDENUMERATION
		Method ObjectEnumerator:AssetEnumerator<AssetType>() Property
			Return Container.ObjectEnumerator()
		End
	#End
	
	Method EntryCount:Int() Property
		#If RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_STACK
			Return Container.Length
		#Elseif RESOURCES_ASSETMANAGER_CONTAINER = MOJOWRAPPER_CONTAINERTYPE_LIST
			Return Container.Count()
		#Else
			Error_Unsupported()
			
			Return 0
		#End
	End
	
	' Fields:
	Field Container:AssetContainer<AssetType>
End

' Exception classes:
Class AssetManager_Exception Extends Throwable Abstract
	' Constructor(s):
	Method New(AssetManager:AssetManager_DebugInterface)
		#If RESOURCES_ASSETMANAGER_DEBUGSTOP_ON_EXCEPTIONS
			DebugStop()
		#End
		
		Self.AssetManager = AssetManager
	End
	
	' Fields:
	Field AssetManager:AssetManager_DebugInterface
End

' This type of exception should be thrown when an operation is impossible.
Class AssetManager_InvalidOperationException Extends AssetManager_Exception
	' Constant variable(s):
	Const ErrorHeader:String = "Invalid asset-manager operation: "
	
	' Constructor(s):
	Method New(AssetManager:AssetManager_DebugInterface, Message:String="")
		' Call the super-class's implementation.
		Super.New(AssetManager)
		
		Self.Message = Message
	End
	
	' Methods:
	' Nothing so far.
	
	' Properties:
	Method ToString:String() Property
		Return ErrorHeader + Message
	End
	
	' Fields:
	Field Message:String
End

' This type of exception should be thrown when an operation is unsupported. (Rarely happens)
Class AssetManager_UnsupportedOperationException Extends AssetManager_Exception
	' Constructor(s):
	Method New(AssetManager:AssetManager_DebugInterface)
		' Call the super-class's implementation.
		Super.New(AssetManager)
	End
	
	' Methods:
	' Nothing so far.
	
	' Properties:
	Method ToString:String() Property
		Return "Unable to carry out asset-manager operation: Unsupported"
	End
End

' Functions:
Function UnsupportedOperation:Void(Manager:AssetManager_DebugInterface)
	#If RESOURCES_ASSETMANAGER_THROW_ERRORS
		New AssetManager_UnsupportedOperationException(Manager)
	#Else
		#If CONFIG = "debug"
			DebugLog("Unsupported operation attempted.")
		#End
		
		#If RESOURCES_ASSETMANAGER_DEBUGSTOP_ON_ERRORS
			DebugStop()
		#End
	#End
	
	Return
End