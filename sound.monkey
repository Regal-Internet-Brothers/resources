Strict

Public

#Rem
	This module does not support non-game targets (Currently).
	
	Normally, this module will not be imported unless support is available.
#End

' Preprocessor related:
#If Not BRL_GAMETARGET_IMPLEMENTED
	#Error "This sub-module is not supported; please use a target that supports the 'BBGame' framework."
#End

#RESOURCES_SOUND_IMPLEMENTED = True
#RESOURCES_SOUND_SYNCHRONOUS_BY_DEFAULT = True ' False

' Imports:

' Internal:
Import resources

Import assetentrymanager

' External (Public):
Import mojo.audio

' External (Private):
Private

#If RESOURCES_ASYNC_ENABLED
	Import mojo.asyncloaders
#End

Public

' Interfaces:

' This acts as the standard call-back interface for the 'SoundEntry' class.
Interface SoundEntryRecipient
	' Methods:
	
	' Call-backs:
	Method OnSoundResourceLoaded:Void(Entry:SoundEntry)
End

' Classes:
Class SoundManager Extends AssetEntryManager<SoundEntry> ' Final
	' Constructor(s):
	Method New(CreateContainer:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(CreateContainer, EntryPoolSize)
	End
	
	Method New(Assets:AssetContainer<SoundEntry>, CopyData:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(Assets, CopyData, EntryPoolSize)
	End
	
	' Methods:
	Method Load:SoundEntry(Entry:SoundEntry, ShouldBuild:Bool=True, CopyFrom:Bool=False, CheckReference:Bool=False, LookForSimilar:Bool=True)
		' Check for errors:
		
		' Make sure we have a valid 'Entry' argument.
		If (Entry = Null) Then
			Return Null
		Endif
		
		' Check if we should look for a similar entry:
		If (LookForSimilar) Then
			' Look for a compatible object:
			For Local S:= Eachin Container ' Sounds ' Self
				If (S.Equals(Entry, CheckReference)) Then
					Return S
				Endif
			Next
		Endif
		
		' Mark the 'Entry' object as shared.
		ShareEntry(Entry)
		
		If (CopyFrom) Then
			' Allocate a new entry-object to act as a "link".
			Local E:= New SoundEntry(Entry, True)
			
			' Add the newly allocated object internally.
			Add(E)
			
			' Check if building was requested:
			If (ShouldBuild) Then
				' Check if a "reference" is already available.
				If (E.Reference = Null) Then ' CheckReference
					' Build the newly created entry.
					BuildEntry(E)
				Endif
			Endif
			
			' Return the newly created object.
			Return E
		Endif
		
		' Add the 'Entry' object internally.
		Add(Entry)
		
		' Check if building was requested:
		If (ShouldBuild) Then
			' Attempt to "build" the entry in question.
			BuildEntry(Entry)
		Endif
		
		' Return that same entry-object.
		Return Entry
	End
	
	' This routine will retrieve a sound-entry based on the input given.
	Method Load:SoundEntry(Path:String, Callback:SoundEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local S:= Eachin Container ' Sounds ' Self
			If (S.Equals(Path)) Then
				S.ExecuteCallbackSelectively(Callback)
				
				Return S
			Endif
		Next
		
		' If we couldn't find a suitable entry, generate one.
		Local Entry:= AllocateEntry(Path)
		
		If (AddInternally) Then
			If (Not Add(Entry) And CareAboutInternalAdd) Then
				DeallocateEntry(Entry)
				
				' Return a 'Null' reference to the user.
				Return Null
			Endif
		Endif
		
		' Build the newly generated entry.
		BuildEntry(Entry)
		
		' Check if we have a call-back to work with:
		If (Callback <> Null) Then
			' Add the call-back specified to the newly generated entry.
			Entry.Add(Callback)
			Entry.ExecuteCallbackSelectively(Callback)
		Endif
		
		' Return the newly built entry.
		Return Entry
	End
	
	#Rem
		The behavior of 'AllocateEntry' and 'AllocateRawEntry' is effectively
		the same as the 'ImageManager' class's implementations.
		
		To put it simply, these commands do not internally
		"add" the generated 'SoundEntry' object.
	#End
	
	' Unlike 'AllocateRawEntry', this command will always
	' produce a properly constructed object every time.
	Method AllocateEntry:SoundEntry()
		Return AllocateRawEntry().Construct()
	End
	
	Method AllocateEntry:SoundEntry(Path:String)
		Return AllocateRawEntry().Construct(Path)
	End
	
	Method AllocateEntry:SoundEntry(A:SoundEntry)
		Return AllocateRawEntry().Construct(A)
	End
	
	' For details on 'DeallocateEntry', please consult the 'AssetEntryManager' class.
	Method DeallocateEntry:Bool(Entry:SoundEntry, CheckDeallocationSafety:Bool=True)
		#If RESOURCES_SAFE
			If (CheckDeallocationSafety) Then
				If (Not CanDeallocate(Entry)) Then
					Return False
				Endif
			Endif
		#End
		
		Return Super.DeallocateEntry(Entry.Release(), False)
	End
	
	' Properties:
	Method Sounds:AssetContainer<SoundEntry>() Property
		Return Self.Container
	End
	
	' Fields:
	' Nothing so far.
End

#Rem
	NOTES:
		* Unlike the 'ImageEntry' class, this class does not support the "managed build model".
#End

#If RESOURCES_ASYNC_ENABLED
Class SoundEntry Extends AssetEntry<Sound, SoundEntryRecipient> Implements IOnLoadSoundComplete ' Final
#Else
Class SoundEntry Extends AssetEntry<Sound, SoundEntryRecipient> ' Final
#End
	' Constructor(s) (Public):
	
	' These constructors exhibit the same behavior as their 'Construct' counterparts:
	Method New(Path:String="", IsLinked:Bool=Default_IsLinked)
		' Call the super-class's implementation.
		Super.New(False)
		
		Construct(Path, IsLinked)
	End
	
	Method New(Entry:SoundEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer)
		' Call the super-class's implementation.
		Super.New(False)
		
		' Call the main implementation.
		Construct(Entry, CopyReferenceData, CopyCallbackContainer)
	End
	
	' If directed to do so, this constructor will always copy the reference of the 'Entry' argument.
	' This means that if construction was not successful, the reference will still be copied.
	' This constructor does not check if the 'Entry' argument is valid; use at your own risk.
	Method Construct:SoundEntry(Entry:SoundEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer)
		If (CopyReferenceData) Then
			' For obvious reasons, this is not a formal assignment.
			Self.Reference = Entry.Reference
		Endif
		
		If (CopyCallbackContainer) Then
			If (Entry.Container <> Null) Then
				EnsureContainer()
				
				AddAssets(Entry)
			Endif
		Endif
		
		Return Construct(Entry.Path, CopyReferenceData)
	End
	
	Method Construct:SoundEntry(Path:String="", IsLinked:Bool=Default_IsLinked)
		' Set the default link-state.
		Self.IsLinked = IsLinked
		
		' Set the internal-path of this entry.
		Self.Path = Path
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	' Constructor(s) (Private):
	Private
	
	Method GenerateReference:Sound(DiscardExistingData:Bool=Default_DestroyReferenceData)
		If (DiscardExistingData) Then
			DestroyReference_Safe()
		Endif
		
		If (Path.Length() > 0) Then
			SetReference(LoadSound(Path))
		Endif
		
		If (Reference = Null) Then
			Throw New SoundNotFoundException()
		Endif
		
		Return Reference
	End
	
	Method GenerateReferenceAsync:Sound(DiscardExistingData:Bool=Default_DestroyReferenceData)
		#If RESOURCES_ASYNC_ENABLED
			' Whether asynchronous loading happens or not, this needs to take place:
			If (DiscardExistingData) Then
				DestroyReference_Safe()
			Endif
			
			If (Path.Length() > 0) Then
				LoadSoundAsync(Path, Self)
				
				#If RESOURCES_SAFE
					Self.WaitingForAsynchronousReference = True
				#End
				
				' Return nothing; this tells the user that
				' the sound is being loaded asynchronously.
				Return Null
			Endif
			
			' If this point was reached, we need to perform operations normally.
			Return GenerateReference(False)
		#Else
			' Asynchronous functionality is disabled, execute the main routine.
			Return GenerateReference(DiscardExistingData)
		#End
	End
	
	Public
	
	' Destructor(s) (Public):
	Method Free:SoundEntry(DestroyReferenceData:Bool=Default_DestroyReferenceData)
		#If RESOURCES_SAFE
			Construct()
		#End
		
		If (DestroyReferenceData) Then
			DestroyReference_Safe()
		Else
			Self.Reference = Null
		Endif
		
		' Release the call-back container.
		ReleaseContainer()
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	Method Release:SoundEntry()
		Return Free(Not IsLinked)
	End
	
	' Destructor(s) (Private):
	Private
	
	Method DestroyReference:Void()
		Self.Reference.Discard()
		Self.Reference = Null
		
		Return
	End
	
	Public
	
	' Methods:
	#If RESOURCES_SOUND_SYNCHRONOUS_BY_DEFAULT
		Method Build:Sound(DiscardExistingData:Bool=Default_DestroyReferenceData)
			Return BuildManual(DiscardExistingData)
		End
	#End
	
	Method ExecuteCallback:Void(Callback:SoundEntryRecipient)
		Callback.OnSoundResourceLoaded(Self)
		
		Return
	End
	
	Method GetReference:Sound()
		#If RESOURCES_SAFE
			If (WaitingForAsynchronousReference) Then
				#If CONFIG = "debug"
					DebugStop()
				#End
				
				' Throw an exception regarding the asynchronous state of the 'Reference' property.
				Throw New AsyncSoundUnavailableException(Self)
				
				' Return, just in case.
				Return Null
			Endif
		#End
		
		Return Super.GetReference()
	End
	
	' Call-backs:
	#If RESOURCES_ASYNC_ENABLED
		Method OnLoadSoundComplete:Void(IncomingReference:Sound, Path:String, Source:IAsyncEventSource=Null)
			If (Path <> Self.Path) Then
				#If RESOURCES_SAFE And CONFIG = "debug"
					DebugStop()
				#End
				
				#If Not RESOURCES_SAFE
					IncomingReference.Discard()
				#End
				
				Return
			Endif
			
			#If RESOURCES_SAFE
				Self.WaitingForAsynchronousReference = False
			#End
			
			SetReference(IncomingReference)
			
			Return
		End
	#End
	
	Method Equals:Bool(Input:SoundEntry, CheckReference:Bool)
		If (CheckReference And (Self.Reference <> Input.Reference)) Then
			Return False
		Endif
		
		Return Equals(Input)
	End
	
	Method Equals:Bool(Input:SoundEntry)
		#Rem
			'If (Input = Null And Self <> Null) Then
			If (Input = Null) Then
				Return False
			Endif
		#End
		
		If (Input = Self) Then
			Return True
		Endif
		
		Return Equals(Input.Path)
	End
	
	Method Equals:Bool(Input_Reference:Sound, Input_Path:String)
		Return ((Self.Reference = Input_Reference) And Equals(Input_Path))
	End
	
	' For structural reasons, this was not optimized further:
	Method Equals:Bool(Input_Path:String)
		If (Path = Input_Path) Then
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' Properties:
	Method ReferenceAvail:Bool() Property
		Return (Self.Reference <> Null)
	End
	
	Method NilRef:Sound() Property
		Return Null
	End
	
	#If RESOURCES_SAFE
		Method IsReady:Bool() Property
			Return Super.IsReady() And Not WaitingForAsynchronousReference
		End
	#End
	
	' Fields (Public):
	Field Path:String
	
	' Fields (Private):
	Private
	
	' Debugging / Reserved:
	
	' These fields are only available if 'RESOURCES_SAFE' is enabled:
	#If RESOURCES_SAFE
		' This is used to represent that loading is happening on another thread.
		Field WaitingForAsynchronousReference:Bool
	#End
	
	Public
End

' Exception classes:

' Extend this class as you see fit.
Class SoundException Extends Throwable Abstract
	' Constructor(s):
	Method New(IsCritical:Bool=True)
		Self.IsCritical = IsCritical
	End
	
	' Methods:
	' Nothing so far.
	
	' Properties:
	Method ToString:String() Property
		Return "Message unavailable."
	End
	
	' Fields:
	
	' Booleans / Flags:
	Field IsCritical:Bool
End

Class SoundNotFoundException Extends SoundException
	' Consturctor(s):
	Method New(Target:SoundEntry)
		' Call the super-class's implementation.
		Super.New(True)
		
		Self.Target = Target
	End
	
	' Methods:
	Method TargetString:String(Target:SoundEntry)
		If (Target = Null) Then
			Return "Unknown"
		Endif
		
		Return Target.Path
	End
	
	' Properties:
	Method ToString:String() Property
		Return "Sound not found: " + TargetString
	End
	
	Method TargetString:String() Property
		Return TargetString(Self.Target)
	End
	
	' Fields:
	Field Target:SoundEntry
End

Class AsyncSoundUnavailableException Extends SoundNotFoundException
	' Constructor(s):
	Method New(Waiting:SoundEntry)
		' Call the super-class's implementation.
		Super.New(Waiting)
		
		' Nothing else so far.
	End
	
	' Methods:
	' Nothing so far.
	
	' Properties:
	Method ToString:String() Property
		Return "Attempted operations requiring an asynchronous ~qsound~q: " + TargetString
	End
	
	' Fields:
	' Nothing so far.
End