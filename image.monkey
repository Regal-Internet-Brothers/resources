#Rem
	TODO:
		* Add support for padding with Mojo 2.
		* Add support for custom handles with Mojo 2.
#End

Strict

Public

' Imports:

' Internal:
Import resources

Import assetentrymanager

' External:
#If Not RESOURCES_MOJO2
	#If RESOURCES_ASYNC_ENABLED
		#RESOURCES_IMAGE_ASYNC_ENABLED = True
	#End
	
	#If BRL_GAMETARGET_IMPLEMENTED
		' Public:
		Import mojo.graphics
		
		' Private:
		Private
		
		#If RESOURCES_IMAGE_ASYNC_ENABLED
			Import mojo.asyncloaders
		#End
		
		Public
	#Else
		' Public:
		Import mojoemulator.graphics
		
		' Private:
		Private
		
		#If RESOURCES_IMAGE_ASYNC_ENABLED
			Import mojoemulator.asyncloaders
		#End
		
		Public
	#End
#Else
	Import mojo2.graphics
#End

' Interfaces:

' This acts as the standard call-back interface for the 'ImageEntry' class.
Interface ImageEntryRecipient
	' Methods:
	
	' Call-backs:
	
	#Rem
		When implementing this method, using 'GetReference' is not required.
		In fact, under this context, it's not even recommended.
		
		The 'GetReference' method is used for informal retrieval, this is considered formal.
	#End
	
	Method OnImageResourceLoaded:Void(Entry:ImageEntry)
End

#Rem
	This interface is used to describe a class as an 'Image' generator.
	
	Basically, if a class implements this interface, it may be used
	to "build" an 'ImageEntry' object's references.
#End

Interface ImageReferenceManager
	' Methods:
	
	#Rem
		These methods follow the models set forth by the 'AssetEntry' class's
		'GenerateReference' and 'GenerateReferenceAsync' methods.
		
		The "return values" of these methods must follow those methods' guidelines.
		
		This means that 'AssignReferenceAsync' must only provide an
		'Image' object if it could not be done asynchronously.
	#End
	
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image(Entry:ImageEntry)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry)
	#End
	
	#Rem
		"Asynchronous" loading may be defined as an implementation sees fit.
		However, the rules set by 'AssignReferenceAsync' still generally apply.
		
		"Loading" does not have to be "asynchronous" if impossible.
	#End
	
	#If Not RESOURCES_MOJO2
		Method AssignReferenceAsync:Image(Entry:ImageEntry)
	#Else
		Method AssignReferenceAsync:Image[](Entry:ImageEntry)
	#End
End

' Classes:

#Rem
	DESCRIPTION:
		* 'ImageManager' objects are used to automate sharing of 'Image' objects.
		This class can also be used to keep track of image-data,
		in order to reduce memory footprints when needed.
	NOTES:
		* Any "entries" provided to an object made from this class are under its control.
		This means that if "forced" manual destruction is requested, entries are not explicitly protected.
		This can be configured to some extent using 'RESOURCES_SAFE' via the preprocessor. Generally speaking,
		this class will take the entries' share-states into account, before illegally mutating data.
		
		This also applies to data passed to this object from other 'ImageManagers' and 'AssetManagers'.
		
		* In the event entries presented inherit from the 'ImageEntry' class,
		their behavior may mutate specific rules set by this class. Such behavior is not recommended,
		as a pool-structure is used internally. If such actions are needed, manual management is ideal,
		and setting the 'IsLinked' flag to 'True' for the object in question is recommended.
		
		* References to 'ImageEntry' objects generally shouldn't
		be used for real-time resource abstraction. Though possible,
		call-back systems are already available.
#End

Class ImageManager Extends AssetEntryManager<ImageEntry>
	' Global variable(s):
	#If Not RESOURCES_MOJO2
		Global DefaultFlags:= Image.DefaultFlags
	#Else
		Global DefaultFlags:= (Image.Filter|Image.Mipmap)
	#End
	
	' Constructor(s):
	Method New(CreateContainer:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(CreateContainer, EntryPoolSize)
	End
	
	Method New(Assets:AssetContainer<ImageEntry>, CopyData:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(Assets, CopyData, EntryPoolSize)
	End
	
	' Methods:
	
	#Rem
		This will attempt to add the 'Entry' object internally.
		Then, if 'ShouldBuild' is enabled, this will attempt to build it.
		
		Building is done using the "abstracted build model",
		and may or may not immediately produce a properly built entry.
		
		To put it simply, this means that 'Load' does not guarantee
		a fully built entry at the time it returns. However, it does guarantee
		that it will be fully built when Mojo responds to it.
		
		The "Meta-data" of the return-object is guaranteed to be available from the get-go.
		
		For details, please read the documentation for the 'ImageEntry' class's 'Build' method.
		
		However, if an equivalent entry exists already, that entry will simply be returned.
		When using this command, it is not safe to expect 'Entry' to be what's returned.
		
		Enabling the 'CopyFrom' argument is generally discouraged, as it may produce unneeded objects.
		Setting 'LookForSimilar' to 'False' is highly unrecommended, as it will likely produce "duplicate" objects.
	#End
	
	Method Load:ImageEntry(Entry:ImageEntry, ShouldBuild:Bool=True, CopyFrom:Bool=False, CheckReference:Bool=False, LookForSimilar:Bool=True)
		' Check for errors:
		
		' Make sure we have a valid 'Entry' argument.
		If (Entry = Null) Then
			Return Null
		Endif
		
		' Check if we should look for a similar entry:
		If (LookForSimilar) Then
			' Look for a compatible object:
			For Local I:= Eachin Container ' Images ' Self
				If (I.Equals(Entry, CheckReference) And I.CheckPosition(Entry.X, Entry.Y)) Then
					Return I
				Endif
			Next
		Endif
		
		' Mark the 'Entry' object as shared.
		ShareEntry(Entry)
		
		If (CopyFrom) Then
			' Allocate a new entry-object to act as a "link".
			Local E:= New ImageEntry(Entry, True)
			
			' Add the newly allocated object internally.
			Add(E)
			
			' Check if building was requested:
			If (ShouldBuild) Then
				' Check if a "reference" is already available.
				If (Not E.ReferenceAvail) Then ' CheckReference
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
	
	' This routine will retrieve an image-entry based on the input given.
	Method Load:ImageEntry(Path:String, FrameCount:Int=1, Flags:Int=DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			If (I.Equals(Path, FrameCount, Flags) And I.CheckPosition(0, 0)) Then
				I.ExecuteCallbackSelectively(Callback)
				
				Return I
			Endif
		Next
		
		' If we couldn't find a suitable entry, generate one.
		Local Entry:= AllocateEntry(Path, FrameCount, Flags)
		
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
			'Entry.Add(Callback)
			Entry.ExecuteCallbackSelectively(Callback)
		Endif
		
		' Return the newly built entry.
		Return Entry
	End
	
	Method Load:ImageEntry(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			If (I.Equals(Path, FrameCount, Flags, FrameWidth, FrameHeight) And I.CheckPosition(0, 0)) Then
				I.ExecuteCallbackSelectively(Callback)
				
				Return I
			Endif
		Next
		
		' If we couldn't find a suitable entry, generate one.
		Local Entry:= AllocateEntry(Path, FrameWidth, FrameHeight, FrameCount, Flags)
		
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
			'Entry.Add(Callback)
			Entry.ExecuteCallbackSelectively(Callback)
		Endif
		
		' Return the newly built entry.
		Return Entry
	End
	
	' This command is not recommended.
	Method Create:ImageEntry(FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			If (I.Equals(FrameWidth, FrameHeight, FrameCount, Flags) And I.CheckPosition(0, 0)) Then
				I.ExecuteCallbackSelectively(Callback)
				
				Return I
			Endif
		Next
		
		' If we couldn't find a suitable entry, generate one.
		Local Entry:= AllocateEntry(FrameWidth, FrameHeight, FrameCount, Flags)
		
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
			'Entry.Add(Callback)
			Entry.ExecuteCallbackSelectively(Callback)
		Endif
		
		' Return the newly built entry.
		Return Entry
	End
	
	#Rem
		The 'AllocateEntry' command (Like 'AllocateRawEntry') does not
		internally add the entry in question. The rules of 'AssetEntryManager' apply here;
		internal containment is not done automatically from this low of a level.
		
		The difference between 'AllocateRawEntry' and 'AllocateEntry' is that
		the output from 'AllocateEntry' will be automatically constructed.
	#End
	
	' Unlike 'AllocateRawEntry', this command will always
	' produce a properly constructed object every time.
	Method AllocateEntry:ImageEntry()
		Return AllocateRawEntry().Construct()
	End
	
	Method AllocateEntry:ImageEntry(Path:String, FrameCount:Int=1, Flags:Int=DefaultFlags)
		Return AllocateRawEntry().Construct(Path, FrameCount, Flags)
	End
	
	Method AllocateEntry:ImageEntry(A:ImageEntry)
		Return AllocateRawEntry().Construct(A)
	End
	
	Method AllocateEntry:ImageEntry(Width:Int, Height:Int, FrameCount:Int, Flags:Int=DefaultFlags, Path:String="")
		Return AllocateRawEntry().Construct(Width, Height, FrameCount, Flags, Path)
	End
	
	Method AllocateEntry:ImageEntry(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=DefaultFlags)
		Return AllocateRawEntry().Construct(Path, FrameWidth, FrameHeight, FrameCount, Flags)
	End
	
	' For details on 'DeallocateEntry', please consult the 'AssetEntryManager' class.
	Method DeallocateEntry:Bool(Entry:ImageEntry, CheckDeallocationSafety:Bool=True)
		#If RESOURCES_SAFE
			If (CheckDeallocationSafety) Then
				If (Not CanDeallocate(Entry)) Then
					Return False
				Endif
			Endif
		#End
		
		Return Super.DeallocateEntry(Entry.Release(), False)
	End
	
	Method CanDeallocate:Bool(Entry:EntryType)
		Return Super.CanDeallocate(Entry) And Entry.CanDeallocate()
	End
	
	' Properties:
	Method Images:AssetContainer<ImageEntry>() Property
		Return Self.Container
	End
	
	' Fields:
	' Nothing so far.
End

#Rem
	DESCRIPTION:
		* An 'AtlasImageManager' is an object which uses Mojo's 'GetImage'
		method in order to reuse the same "surface" object for multiple images.
	NOTES:
		* Since Mojo already handles "source" 'Images' for us, this class can just
		"virtualize" the 'Image' building process further, by using
		the same surface for the same image as it would be on the disk.
		
		* Asynchronous loading is only available for 'ImageEntry'
		objects that are contained by this object. To change this behavior,
		'RESOURCES_SAFE' must be enabled with the preprocessor.
		
		It is not recommended to do this, however.
		
		* On top of the memory saving benefits, this class also allows shared 'Images'
		to have their own handles and flags, without wasting memory at all.
#End

#If RESOURCES_IMAGE_ASYNC_ENABLED
Class AtlasImageManager Extends ImageManager Implements ImageReferenceManager, IOnLoadImageComplete
#Else
Class AtlasImageManager Extends ImageManager Implements ImageReferenceManager
#End
	' Constructor(s):
	
	' Calling up to the super-class's implementation is done through the standard 'ConstructManager' constructor:
	Method New(CreateContainer:Bool=True, BuildAtlasMap:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(CreateContainer, EntryPoolSize)
		
		' Call the main implementation.
		ConstructAtlasImageManager(BuildAtlasMap)
	End
	
	Method New(Assets:AssetContainer<ImageEntry>, BuildAtlasMap:Bool=True, CopyData:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(Assets, CopyData, EntryPoolSize)
		
		' Call the main implementation.
		ConstructAtlasImageManager(BuildAtlasMap)
	End
	
	Method ConstructAtlasImageManager:AtlasImageManager(BuildAtlasMap:Bool=True, CareAboutPreviousAtlasMap:Bool=False)
		If (BuildAtlasMap) Then
			If (CareAboutPreviousAtlasMap) Then
				EnsureAtlasMap()
			Else
				CreateAtlasMap()
			Endif
		Endif
		
		' Return this object, so it may be pooled.
		Return Self
	End
	
	#Rem
		Like 'MakeContainer' this will not create the internal
		"atlas-map", this will only allocate a new object.
		
		To ensure an "atlas-map" is available,
		please use the 'EnsureAtlasMap' command.
		
		If you wish to manually create the
		internal map, please use 'CreateAtlasMap'.
	#End
	
	Method MakeAtlasMap:StringMap<Image>()
		Return New StringMap<Image>()
	End
	
	#Rem
		This command will ensure that the internal
		"atlas-map" exists, even if it has to create one.
		
		If your code requires one to exist, but you are
		unsure of its state, please use this command first.
	#End
	
	Method EnsureAtlasMap:StringMap<Image>()
		If (Self.AtlasMap = Null) Then
			Return CreateAtlasMap()
		Endif
		
		Return Self.AtlasMap
	End
	
	#Rem
		Like 'CreateInternalContainer', this is not safe to use if you
		don't already know the current state of the 'AtlasMap' field.
		
		It's best to use 'EnsureAtlasMap' if you want to make sure one
		exists, but don't care about how allocations are done internally.
	#End
	
	Method CreateAtlasMap:StringMap<Image>()
		' Allocate a new 'StringMap' object, then
		' assign the internal "atlas-map" to it.
		Self.AtlasMap = MakeAtlasMap()
		
		' Return the internal map.
		Return Self.AtlasMap
	End
	
	' Methods:
	
	' This is effectively the same as the 'LoadSegment' command.
	Method LoadAutomaticSegment:ImageEntry(Path:String, X:Int=0, Y:Int=0, FrameCount:Int=1, Flags:Int=DefaultFlags, Callback:ImageEntryRecipient=Null, FrameWidth:Int=0, FrameHeight:Int=0, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		Return LoadSegment(Path, X, Y, FrameWidth, FrameHeight, FrameCount, Flags, Callback, AddInternally, CareAboutInternalAdd)
	End
	
	' This command can be used to load a specific portion of an 'Image' object's surface.
	' Like the standard 'Load' commands, this will seamlessly work with the internal "atlas" map.
	Method LoadSegment:ImageEntry(Path:String, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			' Ensure that the object in question is the equal, and it's located at the same place on the atlas:
			If (I.Equals(Path, FrameCount, Flags, FrameWidth, FrameHeight) And I.CheckPosition(X, Y)) Then
				I.ExecuteCallbackSelectively(Callback)
				
				Return I
			Endif
		Next
		
		' If we couldn't find a suitable entry, generate one.
		Local Entry:= New AtlasImageEntry(Path, X, Y, FrameWidth, FrameHeight, FrameCount, Flags, AtlasImageEntry.Default_IsLinked, True)
		
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
			'Entry.Add(Callback)
			Entry.ExecuteCallbackSelectively(Callback)
		Endif
		
		' Return the newly built entry.
		Return Entry
	End
	
	#Rem
		This command will only provide an "atlas"
		if one has already been generated.
		
		To safely retrieve an "atlas", even if
		one needs to be generated/loaded, please
		use the 'GenerateAtlas' command.
	#End
	
	Method LookupAtlas:Image(Entry:ImageEntry)
		Return LookupAtlas(Entry.Path)
	End
	
	Method LookupAtlas:Image(Path:String)
		Return AtlasMap.Get(Path)
	End
	
	Method GenerateAtlas:Image(Entry:ImageEntry)
		Return GenerateAtlas(Entry.Path)
	End
	
	Method GenerateAtlas:Image(Path:String)
		' Local variable(s):
		
		' Look for an existing "atlas", before trying to generate one:
		Local Atlas:= LookupAtlas(Path)
		
		' Check if we could find one:
		If (Atlas <> Null) Then
			' Give this "atlas" to the user.
			Return Atlas
		Endif
		
		' We were unable to find an "atlas", generate one.
		Return ForceGenerateAtlas(Path)
	End
	
	#If RESOURCES_IMAGE_ASYNC_ENABLED
		' Please refrain from using the 'Flags' argument(s) of these methods.
		Method GenerateAtlasAsync:Void(Entry:ImageEntry, Flags:Int=DefaultFlags)
			#If RESOURCES_SAFE
				Entry.WaitingForAsynchronousReference = True
			#End
			
			GenerateAtlasAsync(Entry.Path, Flags)
			
			Return
		End
		
		Method GenerateAtlasAsync:Void(Path:String, Flags:Int=DefaultFlags)
			GenerateAtlasAsync(Path, Self, Flags)
			
			Return
		End
		
		Method GenerateAtlasAsync:Void(Path:String, Callback:IOnLoadImageComplete, Flags:Int=DefaultFlags)
			LoadImageAsync(Path, 1, Flags, Callback)
			
			Return
		End
	#End
	
	#Rem
		This command should only be used as a last resort.
		
		If an "atlas" already exists, the 'GenerateAtlas'
		method will already provide one for you.
		
		This is used internally, and can be
		used as a last resort if needed.
	#End
	
	Method ForceGenerateAtlas:Image(Path:String)
		#If Not RESOURCES_MOJO2
			Local Atlas:= LoadImage(Path)
		#Else
			Local Atlas:= Image.Load(Path, 0.0, 0.0, DefaultFlags)
		#End
		
		SetAtlas(Atlas, Path)
		
		Return Atlas
	End
	
	Method SetAtlas:Bool(Atlas:Image, Path:String)
		Return AtlasMap.Set(Path, Atlas)
	End
	
	Method BuildEntry:Void(E:ImageEntry, DiscardExistingData:Bool=ImageEntry.Default_DestroyReferenceData)
		If (E.ShouldLoadFromDisk) Then
			E.ManagedBuild(Self, DiscardExistingData)
		Else
			Super.BuildEntry(E, DiscardExistingData)
		Endif
		
		Return
	End
	
	Method BuildEntryManual:Void(E:ImageEntry, DiscardExistingData:Bool=ImageEntry.Default_DestroyReferenceData)
		If (E.ShouldLoadFromDisk) Then
			E.ManagedBuildManual(Self, DiscardExistingData)
		Else
			Super.BuildEntryManual(E, DiscardExistingData)
		Endif
		
		Return
	End
	
	Method BuildEntryAsync:Void(E:ImageEntry, DiscardExistingData:Bool=ImageEntry.Default_DestroyReferenceData)
		If (E.ShouldLoadFromDisk) Then
			E.ManagedBuildAsync(Self, DiscardExistingData)
		Else
			Super.BuildEntryAsync(E, DiscardExistingData)
		Endif
		
		Return
	End
	
	' These overloads exist for the sake of compliance with the 'ImageReferenceManager' interface:
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image(Entry:ImageEntry)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry)
	#End
			Return AssignReference(Entry, True)
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReferenceAsync:Image(Entry:ImageEntry)
	#Else
		Method AssignReferenceAsync:Image[](Entry:ImageEntry)
	#End
			Return AssignReferenceAsync(Entry, True)
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image(Entry:ImageEntry, CallUpOnFailure:Bool, X:Int=0, Y:Int=0)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry, CallUpOnFailure:Bool, X:Int=0, Y:Int=0)
	#End
			Return AssignReference(Entry, Entry.ShouldLoadFromDisk, CallUpOnFailure, X, Y)
		End

	#If Not RESOURCES_MOJO2	
		Method AssignReference:Image(Entry:ImageEntry, Atlas:Image, CallUpOnFailure:Bool=True, X:Int=0, Y:Int=0)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry, Atlas:Image, CallUpOnFailure:Bool=True, X:Int=0, Y:Int=0)
	#End
			Return AssignReference(Entry, Entry.ShouldLoadFromDisk, Atlas, CallUpOnFailure, X, Y)
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image(Entry:ImageEntry, ShouldLoadFromDisk:Bool, CallUpOnFailure:Bool, X:Int=0, Y:Int=0)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry, ShouldLoadFromDisk:Bool, CallUpOnFailure:Bool, X:Int=0, Y:Int=0)
	#End
			If (ShouldLoadFromDisk) Then
				'Local Atlas:= GenerateAtlas(Entry)
				
				Return AssignReference(Entry, ShouldLoadFromDisk, GenerateAtlas(Entry), CallUpOnFailure, X, Y) ' ShouldLoadFromDisk And (Atlas <> Null)
			Endif
			
			Return AssignReference(Entry, False, Null, CallUpOnFailure, X, Y)
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image(Entry:ImageEntry, ShouldLoadFromDisk:Bool, Atlas:Image, CallUpOnFailure:Bool=True, X:Int=0, Y:Int=0)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry, ShouldLoadFromDisk:Bool, Atlas:Image, CallUpOnFailure:Bool=True, X:Int=0, Y:Int=0)
	#End
			' Check if we're loading from the disk:
			#If RESOURCES_SAFE ' And CONFIG <> "debug"
				If (ShouldLoadFromDisk And Atlas <> Null) Then
			#Else
				If (ShouldLoadFromDisk) Then
			#End
					#If RESOURCES_SAFE And CONFIG = "debug"
						If (Entry.FrameCount <= 0) Then
							DebugLog("Invalid frame-count detected.")
							
							DebugStop()
						Endif
						
						If (Entry.FrameWidth <= 0 And Entry.FrameHeight > 0 Or Entry.FrameWidth > 0 And Entry.FrameHeight <= 0) Then
							DebugLog("Invalid frame-size detected.")
							
							DebugStop()
						Endif
					#End
					
					Entry.GrabFrom(Atlas, X, Y)
				Else
					If (CallUpOnFailure) Then
						Super.BuildEntry(Entry, False)
					Endif
				Endif
			
			Return Entry.Reference
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReferenceAsync:Image(Entry:ImageEntry, ShouldLoadFromDisk:Bool, CallUpOnFailure:Bool=True)
	#Else
		Method AssignReferenceAsync:Image[](Entry:ImageEntry, ShouldLoadFromDisk:Bool, CallUpOnFailure:Bool=True)
	#End
			#If RESOURCES_IMAGE_ASYNC_ENABLED
				' Check if we're loading from the disk:
				If (ShouldLoadFromDisk) Then
					Local Atlas:= LookupAtlas(Entry)
					
					If (Atlas <> Null) Then
						Return AssignReference(Entry, True, Atlas, CallUpOnFailure)
					Else
						#If RESOURCES_SAFE
							If (Not Contains(Entry)) Then
								Return AssignReference(Entry, True, CallUpOnFailure)
							Else
						#End
								' Generate the "atlas" for this 'ImageEntry' object asynchronously.
								GenerateAtlasAsync(Entry)
						#If RESOURCES_SAFE
							Endif
						#End
					Endif
				Else
					If (CallUpOnFailure) Then
						Super.BuildEntryAsync(Entry, False)
					Endif
				Endif
				
				Return Entry.Reference
			#Else
				Return AssignReference(Entry, ShouldLoadFromDisk, CallUpOnFailure)
			#End
		End
	
	' Call-backs:
	#If RESOURCES_IMAGE_ASYNC_ENABLED
		Method OnLoadImageComplete:Void(IncomingReference:Image, Path:String, Source:IAsyncEventSource=Null)
			' Check for errors:
			#If RESOURCES_SAFE
				If (IncomingReference = Null) Then
					Return
				Endif
			#End
			
			SetAtlas(IncomingReference, Path)
			
			#If RESOURCES_SAFE And CONFIG = "debug"
				Local EntryFound:Bool = False
			#End
			
			For Local Entry:= Eachin Container
				#If RESOURCES_SAFE
					'If (Entry.Reference = Null) Then
					If (Entry.WaitingForAsynchronousReference) Then
				#End
						If (Entry.Path = Path) Then
							AssignReference(Entry, True, IncomingReference, True)
							
							#If RESOURCES_SAFE And CONFIG = "debug"
								EntryFound = True
							#End
							
							#If RESOURCES_SAFE
								Entry.WaitingForAsynchronousReference = False
							#Else
								'Exit
							#End
						Endif
				#If RESOURCES_SAFE
					Endif
				#End
			Next
			
			#If RESOURCES_SAFE And CONFIG = "debug"
				If (Not EntryFound) Then
					DebugStop()
				Endif
			#End
			
			Return
		End
	#End
	
	' Fields:
	
	' A map of "atlases" used to reduce GPU memory footprints even further.
	Field AtlasMap:StringMap<Image>
End

#Rem
	NOTES:
		* This class uses a specific "reference generation model", which allows for separate objects
		to abstractly provicde an 'Image' reference. Following this same mindset,
		this class also implements the same interface, allowing it to be self-contained.
		
		For details, please see the 'GenerateReference' and 'GenerateReferenceAsync' commands.
#End

#If RESOURCES_IMAGE_ASYNC_ENABLED
Class ImageEntry Extends ManagedAssetEntry<Image, ImageReferenceManager, ImageEntryRecipient> Implements ImageReferenceManager, IOnLoadImageComplete
#Else
#If Not RESOURCES_MOJO2
	Class ImageEntry Extends ManagedAssetEntry<Image, ImageReferenceManager, ImageEntryRecipient> Implements ImageReferenceManager
#Else
	Class ImageEntry Extends ManagedAssetEntry<Image[], ImageReferenceManager, ImageEntryRecipient> Implements ImageReferenceManager
#End
#End
	' Constant variable(s):
	' Nothing so far.
	
	' Global variable(s):
	Global DefaultFlags:= ImageManager.DefaultFlags
	
	' Functions (Public):
	' Nothing so far.
	
	' Functions (Private):
	Private
	
	#If RESOURCES_MOJO2
		' Mojo compatibility layer:
		Function CreateImage:Image[](Width:Int, Height:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, HandleX:Float=0.5, HandleY:Float=0.5)
			Return [New Image(Width, Height, HandleX, HandleY, Flags)]
		End
		
		Function LoadImage:Image[](Path:String, FrameCount:Int=1, Flags:Int=DefaultFlags, HandleX:Float=0.5, HandleY:Float=0.5, Padded:Bool=False)
			Return Image.LoadFrames(Path, FrameCount, Padded, HandleX, HandleY, Flags)
		End
		
		Function LoadImage:Image[](Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=DefaultFlags, HandleX:Float=0.5, HandleY:Float=0.5)
			Return GrabImage(Material.Load(Path, Flags, Null), 0, 0, FrameWidth, FrameHeight, FrameCount, Flags)
		End
		
		Function GrabImage:Image[](I:Image, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, HandleX:Float=0.5, HandleY:Float=0.5)
			Return GrabImage(I.Material, X, Y, FrameWidth, FrameHeight, FrameCount, Flags, HandleX, HandleY)
		End
		
		Function GrabImage:Image[](M:Material, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, HandleX:Float=0.5, HandleY:Float=0.5)
			Local T:= M.GetTexture("ColorTexture")
			
			Local TW:= T.Width
			Local TH:= T.Height
			
			Local Count:= Min((TW / FrameWidth) + (TH / FrameHeight), FrameCount)
			
			Local Output:= New Image[Count]
			
			For Local Entry:= 0 Until Count ' Output.Length
				Local VPos:= (Entry*FrameWidth)
				Local Row:= (VPos / TW)
				Local IX:= ((X+VPos) Mod TW)
				Local IY:= (Row * FrameWidth) ' * FrameHeight
				
				If (Row = 0) Then
					IY += Y
				Endif
				
				Output[Entry] = New Image(M, IX, IY, FrameWidth, FrameHeight, HandleX, HandleY)
			Next
			
			Return Output
		End
	#End
	
	Public
	
	' Constructor(s) (Public):
	
	' These constructors exhibit the same behavior as their 'Construct' counterparts:
	Method New(Path:String="", FrameCount:Int=1, Flags:Int=DefaultFlags, IsLinked:Bool=Default_IsLinked)
		' Call the super-class's implementation.
		Super.New(False)
		
		Construct(Path, FrameCount, Flags, IsLinked)
	End
	
	Method New(Width:Int, Height:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, Path:String="", IsLinked:Bool=Default_IsLinked)
		' Call the super-class's implementation.
		Super.New(False)
		
		' Call the main implementation.
		Construct(Width, Height, FrameCount, Flags, Path, IsLinked)
	End
	
	Method New(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=DefaultFlags, IsLinked:Bool=Default_IsLinked)
		' Call the super-class's implementation.
		Super.New(False)
		
		' Call the main implementation.
		Construct(Path, FrameWidth, FrameHeight, FrameCount, Flags, IsLinked)
	End
	
	Method New(Entry:ImageEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer)
		' Call the super-class's implementation.
		Super.New(False)
		
		' Call the main implementation.
		Construct(Entry, CopyReferenceData, CopyCallbackContainer)
	End
	
	' If directed to do so, this constructor will always copy the reference of the 'Entry' argument.
	' This means that if construction was not successful, the reference will still be copied.
	' This constructor does not check if the 'Entry' argument is valid; use at your own risk.
	Method Construct:ImageEntry(Entry:ImageEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer)
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
		
		Return Construct(Entry.Path, Entry.FrameWidth, Entry.FrameHeight, Entry.FrameCount, Entry.Flags, CopyReferenceData)
	End
	
	Method Construct:ImageEntry(Path:String="", FrameCount:Int=1, Flags:Int=DefaultFlags, IsLinked:Bool=Default_IsLinked)
		Return Construct(Path, 0, 0, FrameCount, Flags, IsLinked)
	End
	
	Method Construct:ImageEntry(Width:Int, Height:Int, FrameCount:Int, Flags:Int=DefaultFlags, Path:String="", IsLinked:Bool=Default_IsLinked)
		Return Construct(Path, Width, Height, FrameCount, Flags, IsLinked)
	End
	
	Method Construct:ImageEntry(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=DefaultFlags, IsLinked:Bool=Default_IsLinked)
		' Set the default link-state.
		Self.IsLinked = IsLinked
		
		' Set the internal-path of this entry.
		Self.Path = Path
		
		Self.FrameWidth = FrameWidth
		Self.FrameHeight = FrameHeight
		Self.FrameCount = FrameCount
		
		Self.Flags = Flags
		
		Construct_Extensions()
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	' This constructor may be used by inheriting classes to
	' restore any extra information back to its default state.
	Method Construct_Extensions:Void()
		' Nothing so far.
		
		Return
	End
	
	' Constructor(s) (Private):
	Private
	
	#If Not RESOURCES_MOJO2
		Method ManagedGenerateReference:Image(Manager:ImageReferenceManager, DiscardExistingData:Bool=Default_DestroyReferenceData)
	#Else
		Method ManagedGenerateReference:Image[](Manager:ImageReferenceManager, DiscardExistingData:Bool=Default_DestroyReferenceData)
	#End
			If (DiscardExistingData) Then
				DestroyReference_Safe()
			Endif
			
			If (Manager = Null) Then
				Return Self.AssignReference(Self)
			Endif
			
			Return Manager.AssignReference(Self)
		End
	
	#Rem
		This command is not guaranteed to be "asynchronous".
		
		If operations could be done asynchronously, the "return-value" of this method will be 'Null'.
		Otherwise, asynchronous behavior could not be followed, and the
		"return-value" will be the internal "reference" of this object (After loading/building).
		
		Behavior of this command, and 'BuildAsync' is susceptible to change.
	#End
	
	#If Not RESOURCES_MOJO2
		Method ManagedGenerateReferenceAsync:Image(Manager:ImageReferenceManager, DiscardExistingData:Bool=Default_DestroyReferenceData)
	#Else
		Method ManagedGenerateReferenceAsync:Image[](Manager:ImageReferenceManager, DiscardExistingData:Bool=Default_DestroyReferenceData)
	#End
			' Whether asynchronous loading happens or not, this needs to take place:
			If (DiscardExistingData) Then
				DestroyReference_Safe()
			Endif
			
			If (Manager = Null) Then
				Return Self.AssignReferenceAsync(Self)
			Endif
			
			Return Manager.AssignReferenceAsync(Self)
		End
	
	Public
	
	' Destructor(s) (Public):
	Method Free:ImageEntry(DestroyReferenceData:Bool=Default_DestroyReferenceData)
		#If RESOURCES_SAFE
			Construct()
		#End
		
		DestroyReference_Safe(DestroyReferenceData)
		
		' Release the call-back container.
		ReleaseContainer()
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	Method Release:ImageEntry()
		Return Free(Not IsLinked)
	End
	
	' Destructor(s) (Private):
	Private
	
	Method DestroyReference:Void()
		#If Not RESOURCES_MOJO2
			Self.Reference.Discard()
		#Else
			For Local I:= Eachin Self.Reference
				I.Discard()
			Next
		#End
		
		Self.Reference = NilRef
		
		Return
	End
	
	Public
	
	' Methods (Public):
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image(Entry:ImageEntry)
	#Else
		Method AssignReference:Image[](Entry:ImageEntry)
	#End
			Return Entry.AssignReference()
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReferenceAsync:Image(Entry:ImageEntry)
	#Else
		Method AssignReferenceAsync:Image[](Entry:ImageEntry)
	#End
			Return Entry.AssignReferenceAsync()
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReference:Image()
	#Else
		Method AssignReference:Image[]()
	#End
			If (ShouldLoadFromDisk) Then
				If (FrameWidth > 0 And FrameHeight > 0) Then
					SetReference(LoadImage(Path, FrameWidth, FrameHeight, FrameCount, Flags))
				Else
					SetReference(LoadImage(Path, FrameCount, Flags))
				Endif
			Else
				SetReference(CreateImage(FrameWidth, FrameHeight, FrameCount, Flags))
			Endif
			
			If (Not ReferenceAvail) Then
				Throw New ImageNotFoundException(Self)
			Endif
			
			Return Reference
		End
	
	#If Not RESOURCES_MOJO2
		Method AssignReferenceAsync:Image()
	#Else
		Method AssignReferenceAsync:Image[]()
	#End
			#If RESOURCES_IMAGE_ASYNC_ENABLED
				If (ShouldLoadFromDisk) Then
					If (FrameWidth < 0 Or FrameHeight < 0) Then
						' Asynchronously load the image-data requested.
						LoadImageAsync(Path, FrameCount, Flags, Self)
						
						#If RESOURCES_SAFE
							Self.WaitingForAsynchronousReference = True
						#End
						
						' Return nothing; this tells the user that
						' the image is being loaded asynchronously.
						Return Null
					Endif
				Endif
			#End
			
			' If this point was reached, we need to perform operations normally.
			Return AssignReference()
		End
	
	Method ExecuteCallback:Void(Callback:ImageEntryRecipient)
		Callback.OnImageResourceLoaded(Self)
		
		Return
	End
	
	#If Not RESOURCES_MOJO2
		Method GetReference:Image()
	#Else
		Method GetReference:Image[]()
	#End
			#If RESOURCES_SAFE
				If (WaitingForAsynchronousReference) Then
					#If CONFIG = "debug"
						DebugStop()
					#End
					
					' Throw an exception regarding the asynchronous state of the 'Reference' property.
					Throw New AsyncImageUnavailableException(Self)
					
					' Return, just in case.
					'Return Null
				Endif
			#End
			
			Return Super.GetReference()
		End
	
	Method GrabFrom:Void(Atlas:Image, X:Int=0, Y:Int=0)
		Local FrameWidth:Int
		Local FrameHeight:Int
		
		If (Self.FrameWidth = 0 And Self.FrameHeight = 0) Then
			FrameWidth = (Atlas.Width()-X) / Self.FrameCount
			FrameHeight = (Atlas.Height()-Y)
		Else
			FrameWidth = Self.FrameWidth
			FrameHeight = Self.FrameHeight
		Endif
		
		#If Not RESOURCES_MOJO2
			SetReference(Atlas.GrabImage(X, Y, FrameWidth, FrameHeight, FrameCount, Flags))
		#Else
			SetReference(GrabImage(Atlas, X, Y, FrameWidth, FrameHeight, FrameCount, Flags))
		#End
		
		Return
	End
	
	#Rem
		These methods act as "grab" routines for the internal reference.
		
		These work as standard "share operations", meaning
		image-data can't be explicitly discarded in the future.
		
		An 'Image' object will only be produced if the internal
		reference exists, and sharing can be done successfully.
		
		These methods do not make formal calls to 'GetReference',
		meaning they are not implicitly capable of throwing access exceptions.
		
		The "grabbing" behavior of these methods is described by Mojo.
		Please keep in mind Mojo's behavior regarding multi-frame "grabbing".
	#End
	
	#If Not RESOURCES_MOJO2
		Method Grab:Image(X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags)
	#Else
		Method Grab:Image[](X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags)
	#End
			' Check for errors:
			
			' Check if we have an internal reference to "grab" from:
			If (Not ReferenceAvail) Then
				Return NilRef
			Endif
			
			#If RESOURCES_SAFE
				If (Self.FrameCount > 1) Then
					Return NilRef
				Endif
			#End
			
			' Make sure we can "share" the internal reference:
			If (Not Share()) Then
				Return NilRef
			Endif
			
			' Use Mojo to "grab" from the internal reference:
			#If Not RESOURCES_MOJO2
				Return Self.Reference.GrabImage(X, Y, FrameWidth, FrameHeight, FrameCount, Flags)
			#Else
				'Function GrabImage:Image[](M:Material, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, HandleX:Float=0.5, HandleY:Float=0.5)
				Return GrabImage(Self.Reference[0], X, Y, FrameWidth, FrameHeight, FrameCount, Flags) ' Self.Reference[0].Material
			#End
		End
	
	#If Not RESOURCES_MOJO2
		Method Grab:Image(X:Int=0, Y:Int=0)
	#Else
		Method Grab:Image[](X:Int=0, Y:Int=0)
	#End
			Return Grab(X, Y, Self.FrameWidth, Self.FrameHeight, Self.FrameCount, Self.Flags)
		End
	
	' This is used for "atlas" optimization purposes.
	' By default, 'ImageEntry' objects do not have positions.
	Method CheckPosition:Bool(X:Int=0, Y:Int=0)
		Return ((X = 0) And (Y = 0))
	End
	
	' Call-backs:
	#If RESOURCES_IMAGE_ASYNC_ENABLED
		Method OnLoadImageComplete:Void(IncomingReference:Image, Path:String="", Source:IAsyncEventSource=Null)
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
			
			' Set the internal reference to the incoming reference.
			SetReference(IncomingReference)
			
			Return
		End
	#End
	
	Method Equals:Bool(Input:ImageEntry, CheckReference:Bool)
		If (CheckReference) Then
			If (Not ResourceEquals(Self.Reference, Input.Reference)) Then
				Return False
			Endif
		Endif
		
		Return Equals(Input)
	End
	
	Method Equals:Bool(Input:ImageEntry)
		#Rem
			'If (Input = Null And Self <> Null) Then
			If (Input = Null) Then
				Return False
			Endif
		#End
		
		If (Input = Self) Then
			Return True
		Endif
		
		Return Equals(Input.Path, Input.FrameCount, Input.Flags, Input.FrameWidth, Input.FrameHeight)
	End
	
	#If Not RESOURCES_MOJO2
		Method Equals:Bool(Input_Reference:Image, Input_FrameCount:Int=1, Input_Flags:Int=DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
	#Else
		Method Equals:Bool(Input_Reference:Image[], Input_FrameCount:Int=1, Input_Flags:Int=DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
	#End
			Return (ResourceEquals(Self.Reference, Input_Reference) And Equals(Input_FrameWidth, Input_FrameHeight, Input_FrameCount, Input_Flags))
		End
	
	#If Not RESOURCES_MOJO2
		Method Equals:Bool(Input_Reference:Image, Input_Path:String="", Input_FrameCount:Int=1, Input_Flags:Int=DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
	#Else
		Method Equals:Bool(Input_Reference:Image[], Input_Path:String="", Input_FrameCount:Int=1, Input_Flags:Int=DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
	#End
			Return (ResourceEquals(Self.Reference, Input_Reference) And Equals(Input_Path, Input_FrameCount, Input_Flags, Input_FrameWidth, Input_FrameHeight))
		End
	
	Method Equals:Bool(Input_Path:String, Input_FrameCount:Int=1, Input_Flags:Int=DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
		Return ((Path = Input_Path) And (FrameWidth = Input_FrameWidth And FrameHeight = Input_FrameHeight And FrameCount = Input_FrameCount And Flags = Input_Flags)) ' Equals(Input_FrameWidth, Input_FrameHeight, Input_FrameCount, Input_Flags)
	End
	
	Method Equals:Bool(Input_FrameWidth:Int=0, Input_FrameHeight:Int=0, Input_FrameCount:Int=1, Input_Flags:Int=DefaultFlags)
		Return Equals("", Input_FrameCount, Input_Flags, Input_FrameWidth, Input_FrameHeight)
	End
	
	#If RESOURCES_MOJO2
		Method ResourceEquals:Bool(X:Image[], Y:Image[])
			Local Length:= X.Length()
			
			If (Length <> Y.Length()) Then
				Return False
			Endif
			
			For Local I:= 0 Until Length
				If (X[I] <> Y[I]) Then
				'If (Not Equals(X[I], Y[I])) Then
					Return False
				Endif
			Next
			
			' Return the default response.
			Return True
		End
	#Else
		Method ResourceEquals:Bool(X:Image, Y:Image)
			Return (X = Y)
		End
	#End
	
	' Methods (Private):
	Private
	
	' Nothing so far.
	
	Public
	
	' Properties:
	Method CanDeallocate:Bool() Property
		Return True
	End
	
	Method ShouldLoadFromDisk:Bool() Property
		Return (Path.Length() > 0)
	End
	
	Method ReferenceAvail:Bool() Property
		#If Not RESOURCES_MOJO2
			Return (Reference <> Null)
		#Else
			Return (Reference.Length() > 0)
		#End
	End
	
	#If Not RESOURCES_MOJO2
		Method NilRef:Image() Property
			Return Null
		End
	#Else
		Method NilRef:Image[]() Property
			Return []
		End
	#End
	
	#If RESOURCES_SAFE
		Method IsReady:Bool() Property
			Return Super.IsReady() And Not WaitingForAsynchronousReference
		End
	#End
	
	Method Frames:Int() Property
		#If Not RESOURCES_MOJO2
			If (Reference = Null) Then
				Return 0
			Endif
			
			Return Reference.Frames()
		#Else
			Return Reference.Length()
		#End
	End
	
	Method X:Int() Property
		Return 0
	End
	
	Method Y:Int() Property
		Return 0
	End
	
	Method X:Void(Value:Int) Property
		Return
	End
	
	Method Y:Void(Value:Int) Property
		Return
	End
	
	' Fields (Public):
	Field Path:String
	
	Field FrameWidth:Int
	Field FrameHeight:Int
	Field FrameCount:Int
	
	Field Flags:Int
	
	#If RESOURCES_MOJO2
		Field HandleX:Float, HandleY:Float
	#End
	
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

#Rem
	DESCRIPTION:
		* 'AtlasImageEntry' objects are 'ImageEntry' objects
		which specify where in an "atlas" the underlying 'Image' reference begins.
	NOTES:
		* Objects made from this class are not normally pooled by 'ImageManager' objects.
		This can be changed manually when constructing one, however, re-use of
		this object will not be done as an 'AtlasImageEntry'.
		
		There is no plan to create a specific 'ImageManager'
		class that deals with this class directly.
		
		The 'AtlasImageManager' class uses this class, but it does not
		distinguish between this class and the 'ImageEntry' class.
#End

Class AtlasImageEntry Extends ImageEntry
	' Constant variable(s):
	
	' Defaults:
	Const Default_CanBePooled:Bool = False
	
	' Constructor(s):
	Method New(Path:String="", FrameCount:Int=1, Flags:Int=DefaultFlags, X:Int=0, Y:Int=0, IsLinked:Bool=Default_IsLinked, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Path, FrameCount, Flags, IsLinked)
		
		Self.X = X
		Self.Y = Y
		
		Self.CanBePooled = CanBePooled
	End
	
	Method New(Width:Int, Height:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, X:Int=0, Y:Int=0, Path:String="", IsLinked:Bool=Default_IsLinked, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Width, Height, FrameCount, Flags, Path, IsLinked)
		
		Self.X = X
		Self.Y = Y
		
		Self.CanBePooled = CanBePooled
	End
	
	Method New(Path:String, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=DefaultFlags, IsLinked:Bool=Default_IsLinked, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Path, FrameWidth, FrameHeight, FrameCount, Flags, IsLinked)
		
		Self.X = X
		Self.Y = Y
		
		Self.CanBePooled = CanBePooled
	End
	
	Method New(Entry:ImageEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Entry, CopyReferenceData, CopyCallbackContainer)
		
		Self.X = 0
		Self.Y = 0
		
		Self.CanBePooled = CanBePooled
	End
	
	Method New(Entry:AtlasImageEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Entry, CopyReferenceData, CopyCallbackContainer)
		
		Self.X = Entry.X
		Self.Y = Entry.Y
		
		Self.CanBePooled = CanBePooled
	End
	
	Method Construct_Extensions:Void()
		'#If RESOURCES_SAFE
		Self.X = 0
		Self.Y = 0
		'#End
		
		' Call the super-class's implementation.
		Super.Construct_Extensions()
		
		Return
	End
	
	' Destructor(s):
	Method Free:ImageEntry(DestroyReferenceData:Bool=Default_DestroyReferenceData)
		Self.X = 0
		Self.Y = 0
		
		' Call the super-class's implementation.
		Return Super.Free(DestroyReferenceData)
	End
	
	' Methods:
	
	#Rem
		These overloads use the internal "atlas-position" fields
		in order to properly offset global operations on
		this object's internal 'Image' reference.
		
		This means the 'X' and 'Y' fields are relied upon,
		and should not misrepresent the underlying 'Image' reference.
		
		If this object is being reused as an 'ImageEntry' object,
		through a pool, or other means, operations can be assumed as normal.
	#End
	
	Method GrabFrom:Void(Atlas:Image, X:Int=0, Y:Int=0)
		Super.GrabFrom(Atlas, Self.X+X, Self.Y+Y)
		
		Return
	End
	
	#Rem
		If you are concerned with safety, please use this command instead of 'Grab'.
		
		This can be used to "grab" from the same segment of the "atlas" this
		object's internal 'Image' was made from.
		
		This is only needed if the aforementioned 'Image' reference can't
		be "grabbed from" by Mojo (Broken into more than one frame).
		
		If this already contains a "grabbable" (Single-frame) 'Image', and the
		'CheckInternal' argument is set to 'True', the standard implementation will be used.
		
		This means an "atlas" will not be checked for.
		
		If an external atlas was used, an "internal share operation" will not be performed.
		
		The 'X' and 'Y' arguments of this command should be assumed
		as pre-offset by this object's "atlas-position".
		
		If the 'ForceAtlasCreation' argument is enabled, instead of just looking for
		an existing atlas, an optimized generation routine will be used. In other words,
		if an atlas couldn't be found, it'll generate/load one.
		
		This behavior can be unwanted, and because of that, 'ForceAtlasCreation' defaults to 'False'.
	#End
	
	#If Not RESOURCES_MOJO2
		Method GrabFromAtlas:Image(AtlasManager:AtlasImageManager, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, CheckInternal:Bool=True, ForceAtlasCreation:Bool=False)
	#Else
		Method GrabFromAtlas:Image[](AtlasManager:AtlasImageManager, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=DefaultFlags, CheckInternal:Bool=True, ForceAtlasCreation:Bool=False)
	#End
			' Check if we can use the standard implementation of 'Grab':
			If (CheckInternal And Frames = 1) Then
				Return Grab(X, Y, FrameWidth, FrameHeight, FrameCount, Flags)
			Endif
			
			' Check for errors:
			If (AtlasManager = Null) Then
				Return NilRef
			Endif
			
			' Local variable(s):
			Local Atlas:Image
			
			' Look for a valid "atlas" to "grab" from:
			If (Not ForceAtlasCreation) Then
				' This will fail if a valid "atlas" doesn't already exist.
				Atlas = AtlasManager.LookupAtlas(Self)
			Else
				' This isn't the best choice, but it works.
				' Basically, if an "atlas" can't be found,
				' this will force one to be generated/loaded.
				Atlas = AtlasManager.GenerateAtlas(Self)
			Endif
			
			If (Atlas = Null) Then
				Return NilRef
			Endif
			
			' We found an "atlas" to work with, "grab" a portion of it.
			#If Not RESOURCES_MOJO2
				Return Atlas.GrabImage(Self.X+X, Self.Y+Y, FrameWidth, FrameHeight, FrameCount, Flags)
			#Else
				Return GrabImage(Atlas, Self.X+X, Self.Y+Y, FrameWidth, FrameHeight, FrameCount, Flags)
			#End
		End
	
	Method CheckPosition:Bool(X:Int=0, Y:Int=0)
		Return (Self.X = X) And (Self.Y = Y)
	End
	
	' Properties:
	Method CanDeallocate:Bool() Property
		Return Self.CanBePooled And Super.CanDeallocate()
	End
	
	Method X:Int() Property Final
		Return Self._X
	End
	
	Method Y:Int() Property Final
		Return Self._Y
	End
	
	Method X:Void(Value:Int) Property Final
		Self._X = Value
		
		Return
	End
	
	Method Y:Void(Value:Int) Property Final
		Self._Y = Value
		
		Return
	End
	
	' Fields (Protected):
	Protected
	
	Field _X:Int, _Y:Int
	
	Public
	
	' Booleans / Flags:
	Field CanBePooled:Bool
End

' Exception classes:

' Extend this class as you see fit.
Class ImageException Extends Throwable Abstract
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

Class ImageNotFoundException Extends ImageException
	' Consturctor(s):
	Method New(Target:ImageEntry)
		' Call the super-class's implementation.
		Super.New(True)
		
		Self.Target = Target
	End
	
	' Methods:
	Method TargetString:String(Target:ImageEntry)
		If (Target = Null) Then
			Return "Unknown"
		Endif
		
		Return Target.Path
	End
	
	' Properties:
	Method ToString:String() Property
		Return "Image not found: " + TargetString
	End
	
	Method TargetString:String() Property
		Return TargetString(Self.Target)
	End
	
	' Fields:
	Field Target:ImageEntry
End

Class AsyncImageUnavailableException Extends ImageNotFoundException
	' Constructor(s):
	Method New(Waiting:ImageEntry)
		' Call the super-class's implementation.
		Super.New(Waiting)
		
		' Nothing else so far.
	End
	
	' Methods:
	' Nothing so far.
	
	' Properties:
	Method ToString:String() Property
		Return "Attempted operations requiring an asynchronous ~qimage~q: " + TargetString
	End
	
	' Fields:
	' Nothing so far.
End