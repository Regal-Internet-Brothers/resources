Strict

Public

' Imports:
Import resources
Import assetentrymanager

' Interfaces:
' Nothing so far.

' Classes:

#Rem
	DESCRIPTION:
		* This class is used to automate sharing of a single resource via a common object.
		
		Basically, this can be used with an 'AssetEntryManager', in order to reduce
		loading the same asset into memory many times over. This can be used alongside 'AssetEntryManager'
		in order to abstract the process of actually loading the asset. This means the loading process
		can be handled asynchronously, or in any kind of configuration needed.
	NOTES:
		* The 'ReferenceType' argument acts as the asset/resource type this entry represents.
		
		* The 'ExternalEntryType' argument should effectively be the exact same type as your inheriting class.
		Alternatively, this could be used for interface functionality.
		
		* Proper construction of 'AssetEntry' objects should be handled by inheriting classes.
		Because of this, this class does not have proper (Initial) constructors.
		The provided constructors are simply "pass-throughs" to the 'AssetManager' class.
		
		* All 'AssetEntry' objects also double as 'AssetManagers' themselves;
		this is done for the sake of standardized call-back management.
		
		* The "call-back" system this class employs may be used to manage active references
		to an object made from an inheriting class. This is completely implementation driven, however.
#End

Class AssetEntry<ReferenceType, CallbackType> Extends AssetManager<CallbackType> Abstract
	' Constant variable(s):
	
	' Defaults:
	
	' Booleans / Flags:
	Const Default_DestroyReferenceData:Bool = True ' False
	Const Default_CopyReferenceData:Bool = True ' False
	Const Default_CopyCallbackContainer:Bool = False ' True
	Const Default_IsLinked:Bool = False
	
	' Constructor(s):
	
	' These constructors are just "pass-throughs" to the 'AssetManager' class:
	Method New(CreateContainer:Bool=True)
		' Call the super-class's implementation.
		Super.New(CreateContainer)
	End
	
	Method New(Assets:AssetContainer<AssetType>, CopyData:Bool=True)
		' Call the super-class's implementation.
		Super.New(Assets, CopyData)
	End
	
	' These methods are not complete, please implement them yourself (Used for resource loading):
	Method GenerateReference:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData) Abstract
	
	#Rem
		This command does not make any guarantees to be "asynchronous".
		
		If operations could be done asynchronously, the "return-value" of this method should be 'Null'.
		
		Otherwise, if asynchronous behavior could not be followed, and the "return-value" should be the
		internal "reference" of this object (After loading/building).
	#End
	
	Method GenerateReferenceAsync:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData) Abstract
	
	' Destructor(s) (Public):
	Method DestroyReference:Void() Abstract
	
	Method DestroyReference_Safe:Void(ShouldDestroy:Bool)
		If (ShouldDestroy And Self.Reference <> Null) Then
			' This routine will handle setting the internal reference to 'Null'.
			DestroyReference()
		Else
			Self.Reference = Null
		Endif
		
		Return
	End
	
	Method DestroyReference_Safe:Void()
		DestroyReference_Safe(Not IsLinked)
		
		Return
	End
	
	' Destructor(s) (Private):
	Private
	
	' Nothing so far.
	
	Public
	
	' Methods (Public):
	
	#Rem
		This command will provide standard behavior if this object
		doesn't already have an internal-reference to the 'ReferenceMask' object.
		Assuming this object does already have a reference to the 'ReferenceMask'
		('Null' works just as well), call-back collection will not be required,
		and the call-back specified will be automatically executed.
	#End
	
	Method Add:Bool(CallbackEntry:CallbackType, ReferenceMask:ReferenceType=Null)
		If (Self.Reference <> ReferenceMask) Then
			' Execute the specified call-back right away.
			ExecuteCallback(CallbackEntry)
			
			' Don't bother continuing, we've done our job.
			Return True
		Endif
		
		' Make sure the call-back container exists.
		EnsureContainer()
		
		Return AddAsset(CallbackEntry)
	End
	
	' For a version of 'Remove' without the container-check, please use 'QuickRemove'.
	Method Remove:Bool(CallbackEntry:CallbackType)
		If (Self.Container = Null) Then
			Return True ' False
		Endif
		
		Return RemoveAsset(Asset)
	End
	
	#Rem
		These are mainly for internal functionality; use at your own risk.
		
		The behavior of these commands is not directly dictated by the 'AssetManager' class.
	#End
	
	#Rem
		This provides a version of 'Add' without the extra overhead of the advanced checks.
		Please keep in mind that 'Add' is standard, whereas this is not. You shouldn't
		bother using this command unless you're fully aware of the state of this object.
		
		Also take note that the internal call-back container may not exist when using this.
		Unlike 'Add', this won't make sure it has been created already.
	#End
	
	Method QuickAdd:Bool(CallbackEntry:CallbackType)
		Return AddAsset(CallbackEntry)
	End
	
	' Unlike 'AddAssets', this command will back every "add" using 'QuickAdd'.
	Method QuickAddAssets:Bool(Entries:AssetManager<CallbackType>)
		For Local Entry:= Eachin Entry
			QuickAdd(Entry)
		Next
		
		' Return the default response.
		Return True
	End
	
	' As stated above, please use 'Remove' for normal purposes.
	Method QuickRemove:Bool(CallbackEntry:CallbackType)
		Return RemoveAsset(CallbackEntry)
	End
	
	#Rem
		This method is called every time this object
		is shared between two 'AssetManagers'.
		
		The return value of this method should reflect
		the current "link state" of this object.
		
		If this were to return 'False',
		effects would be context sensitive.
	#End
	
	Method Share:Bool()
		Self.IsLinked = True
		
		' Return the current link-state.
		Return True ' IsLinked
	End
	
	#Rem
		The 'Build' command is partially abstracted from the synchronous/asynchronous structure.
		
		Like 'BuildAsync', and similar functionality, the "return-value"
		of this command is not guaranteed to be valid.
		
		In the event asynchronous loading/building was preferred, this will return 'Null'.
		Any uses of 'Build' should be thought of as "abstracted" from the loading/building process.
		
		Explicitly requiring a 'ReferenceType' object to be output
		from this command is considered non-standard. Such
		behavior should only be attempted using 'BuildManual'.
		
		Behavior of this command is currently dependent on 'BuildAsync'.
		Inheriting classes may redefine the default behavior of this command as they please.
		
		This system is described by this module as the "abstracted build model".
	#End
	
	Method Build:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return BuildAsync(DiscardExistingData)
	End
	
	' This method is guaranteed to be "synchronous". This means you're immediately
	' given a 'ReferenceType' object to work with. If this effect is needed, use this command.
	' If you are able to abstract yourself from this model, please use 'Build'.
	Method BuildManual:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return GenerateReference(DiscardExistingData)
	End
	
	' This method is not guaranteed to be "asynchronous", however, it is preferred.
	' For details on the behavior of this command, please see 'GenerateReferenceAsync'.
	' Behavior of this command, and 'GenerateReferenceAsync' is susceptible to change.
	Method BuildAsync:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return GenerateReferenceAsync(DiscardExistingData)
	End
	
	#Rem
		Using this command acts as an "informal" retrieval request.
		
		In the even the internal "reference" could not be found,
		behavior is implementation-dependent. This means an inheriting
		class could throw an exception if this was used incorrectly.
		
		Please refrain from using this method.
	#End
	
	Method GetReference:ReferenceType() ' Property
		Return Self.Reference
	End
	
	' This acts as the "formal" assignment command for reference assignment.
	Method SetReference:Void(Ref:ReferenceType, RemoveExistingCallbacks:Bool=True)
		Self.Reference = Ref
		
		' Check if the internal-reference points to something:
		If (Self.Reference <> Null) Then
			' Check if standard call-back activation was requested:
			If (RemoveExistingCallbacks) Then
				' Activate any tethered call-backs.
				ActivateCallbacks()
			Else
				' Instead of properly activating tethered call-backs,
				' execute them, so they may be activated
				' and/or executed at a later date.
				ExecuteCallbacks()
			Endif
		Endif
		
		Return
	End
	
	#Rem
		This acts as the standard call-back activation routine.
		Basically, this will handle activating all of the tethered call-backs,
		as well as "releasing" their internal-container for you.
		
		This command will only return 'False' if
		call-backs could/should not be called.
	#End
	
	Method ActivateCallbacks:Bool()
		' Execute each of the call-backs.
		If (ExecuteCallbacks()) Then
			' Release the internal container.
			ReleaseContainer()
			
			' Tell the user that call-backs were "activated".
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' To normally activate/execute call-backs, please use 'ActivateCallbacks'.
	' This will not remove the call-back objects from the internal container.
	Method ExecuteCallbacks:Bool()
		' Check for errors:
		
		' Make sure that the internal container exists:
		If (Container = Null) Then
			Return False
		Endif
		
		For Local Entry:= Eachin Container ' Self
			ExecuteCallback(Entry)
		Next
		
		' Return the default response.
		Return True
	End
	
	Method ExecuteCallback:Void(Entry:CallbackType) Abstract
	
	#Rem
		This method may be overridden as inheriting classes see fit.
		
		This is commonly used to only execute a call-back,
		if it isn't already "queued" internally.
		
		The 'Callback' argument could be 'Null' under several circumstances,
		please keep this in mind when overriding this method.
	#End
	
	Method ExecuteCallbackSelectively:Void(Callback:CallbackType)
		' Check for errors:
		If (Callback = Null) Then
			Return
		Endif
		
		If (Not Contains(Callback)) Then
			If (IsReady) Then
				ExecuteCallback(Callback)
			Else
				Add(Callback)
			Endif
		Endif
		
		Return
	End
	
	#Rem
		This will release the internal call-back container.
		
		Clearing the internal-container before changing
		the reference to it is not usually ideal. However, there is
		support for it, in case you have an external reference to it.
		
		To enable this behavior, please enable
		'RESOURCES_SAFE' with the preprocessor.
		
		Even then, clearing is still not ideal, as the
		reference is no longer set to anything afterward.
		
		It is recommended to call 'ExecuteCallbacks' before using this.
		
		Alternatively, the standard way of doing both of these
		actions is to call the 'ActivateCallbacks' method.
	#End
	
	Method ReleaseContainer:Void()
		#If RESOURCES_SAFE
			' Usage of this command is always safe.
			ClearContainer()
		#End
		
		' Set the internal-container to 'Null'.
		Self.Container = Null
		
		Return
	End
	
	' Methods (Private):
	Private
	
	Method AddAsset:Bool(Asset:CallbackType)
		Return Super.AddAsset(Asset)
	End
	
	Method RemoveAsset:Bool(Asset:CallbackType)
		Return Super.RemoveAsset(Asset)
	End
	
	Public
	
	' Properties:
	
	' Commonly used for asynchronous load-checks.
	' Such checks are unneeded by proper call-backs.
	Method IsReady:Bool() Property
		Return (Self.Reference <> Null)
	End
	
	' Fields:
	
	#Rem
		A reference to the resource this object represents. "Formal" assignments
		can be done via 'SetReference'. If you are externally retrieving
		this reference, please use 'GetReference'.
	#End
	
	Field Reference:ReferenceType
	
	' Booleans / Flags:
	
	' This flag specifies if this entry is externally
	' linked to another "entry" or "manager" object.
	Field IsLinked:Bool
End

#Rem
	DESCRIPTION:
		* 'ManagedAssetEntry' objects are objects that can be "built" by external objects.
		
		How this is handled is up to inheriting classes, but this
		class acts as an easy to use system for "managed entires".
	NOTES:
		* Internal "reference" generation is not needed when inheriting
		from this class, but it is recommended to do so when possible.
		
		This means that using 'Build', 'GenerateReference', and related
		"unmanaged" methods will result in undefined behavior. For details,
		please view the below documentation regarding 'GenerateReference'.
		
		* The 'ReferenceGenerator' argument is used to specify what type
		should be assumed as the type that will generate this object's
		"reference" (When using 'ManagedBuild', and similar commands).
		
		With that in mind, this can be handled "virtually" by using an interface, rather than
		a concrete implementation. Likewise, you could create a scheme which has this class
		implement this interface as well, letting it be its own "generator".
#End

Class ManagedAssetEntry<ReferenceType, ReferenceGenerator, CallbackType> Extends AssetEntry<ReferenceType, CallbackType> Abstract
	' Constructor(s):
	Method New(CreateContainer:Bool=True)
		' Call the super-class's implementation.
		Super.New(CreateContainer)
	End
	
	Method New(Assets:AssetContainer<AssetType>, CopyData:Bool=True)
		' Call the super-class's implementation.
		Super.New(Assets, CopyData)
	End
	
	' Methods:
	Method ManagedGenerateReference:ReferenceType(Manager:ReferenceGenerator, DiscardExistingData:Bool=Default_DestroyReferenceData) Abstract
	Method ManagedGenerateReferenceAsync:ReferenceType(Manager:ReferenceGenerator, DiscardExistingData:Bool=Default_DestroyReferenceData) Abstract
	
	#Rem
		The 'Generator' argument (Found on the "ManagedBuild" commands) is
		used to represent the 'ReferenceGenerator' object attempting to build this "entry".
		
		It is up to implementing classes if this should require a 'ReferenceGenerator' object or not.
		A general rule of thumb is to not bother requiring it, unless you intend to build
		a system which further abstracts the asset management process.
		
		As described above, one option is to use an interface as your 'ReferenceGenerator' argument.
		From there, you could have a "manager" class of some kind (Possibly based on 'AssetEntryManager'),
		which would generate the internal reference for this "entry". On top of that, you could implement
		that interface yourself, using your inheriting implementation of this class. Then you could simply
		use this object as your "generator" if one was not specified beforehand.
		
		Behavior is implementation-defined, and should be expected as such. "Managed builds" are not normal
		"builds", and they tend to be implemented using abstract systems (Interfaces, for example).
	#End
	
	Method ManagedBuild:ReferenceType(Generator:ReferenceGenerator, DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return ManagedBuildAsync(Generator, DiscardExistingData)
	End
	
	Method ManagedBuildManual:ReferenceType(Generator:ReferenceGenerator, DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return ManagedGenerateReference(Generator, DiscardExistingData)
	End
	
	Method ManagedBuildAsync:ReferenceType(Generator:ReferenceGenerator, DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return ManagedGenerateReferenceAsync(Generator, DiscardExistingData)
	End
	
	#Rem
		These commands will default to calling the "managed" versions.
		This means we can't supply a 'ReferenceGenerator' object, so this class passes 'Null'.
		
		If your own 'ManagedAssetEntry' class can generate a default
		reference, it's best to use it here (By overriding these).
		
		A good example being if your inheriting class implements a common
		interface, in order to provide default behavior in these situations.
		
		Any class that inherits this class, but doesn't override these
		methods is following this mindset.
		
		Using these methods is considered an "unsafe" action, and will result in
		undefined behavior under this context. Please keep this in mind.
	#End
	
	Method GenerateReference:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return ManagedGenerateReference(Null, DiscardExistingData)
	End
	
	Method GenerateReferenceAsync:ReferenceType(DiscardExistingData:Bool=Default_DestroyReferenceData)
		Return ManagedGenerateReferenceAsync(Null, DiscardExistingData)
	End
	
	' Fields:
	' Nothing so far.
End