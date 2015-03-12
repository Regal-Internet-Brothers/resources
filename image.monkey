Strict

Public

' Preprocessor related:
' Nothing so far.

' Imports (Internal):
Import resources

Import assetentrymanager

' Imports (External):
#If BRL_GAMETARGET_IMPLEMENTED
	Import mojo.graphics
	
	#If RESOURCES_ASYNC_ENABLED
		Import mojo.asyncloaders
	#End
#Else
	Import mojoemulator.graphics
	
	#If RESOURCES_ASYNC_ENABLED
		Import mojoemulator.asyncloaders
	#End
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
	
	Method AssignReference:Image(Entry:ImageEntry)
	
	#Rem
		"Asynchronous" loading may be defined as an implementation sees fit.
		However, the rules set by 'AssignReferenceAsync' still generally apply.
		
		"Loading" does not have to be "asynchronous" if impossible.
	#End
	
	Method AssignReferenceAsync:Image(Entry:ImageEntry)
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
				If (I.Equals(Entry, CheckReference)) Then
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
	
	' This routine will retrieve an image-entry based on the input given.
	Method Load:ImageEntry(Path:String, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			If (I.Equals(Path, FrameCount, Flags)) Then
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
		
		' Check if we have a call-back to work with:
		If (Callback <> Null) Then
			' Add the call-back specified to the newly generated entry.
			Entry.Add(Callback)
		Endif
		
		' Build the newly generated entry.
		BuildEntry(Entry)
		
		' Return the newly built entry.
		Return Entry
	End
	
	Method Load:ImageEntry(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			If (I.Equals(Path, FrameCount, Flags, FrameWidth, FrameHeight)) Then
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
		
		' Check if we have a call-back to work with:
		If (Callback <> Null) Then
			' Add the call-back specified to the newly generated entry.
			Entry.Add(Callback)
		Endif
		
		' Build the newly generated entry.
		BuildEntry(Entry)
		
		' Return the newly built entry.
		Return Entry
	End
	
	Method Create:ImageEntry(FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		For Local I:= Eachin Container ' Images ' Self
			If (I.Equals(FrameWidth, FrameHeight, FrameCount, Flags)) Then
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
		
		' Check if we have a call-back to work with:
		If (Callback <> Null) Then
			' Add the call-back specified to the newly generated entry.
			Entry.Add(Callback)
		Endif
		
		' Build the newly generated entry.
		BuildEntry(Entry)
		
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
	
	Method AllocateEntry:ImageEntry(Path:String, FrameCount:Int=1, Flags:Int=Image.DefaultFlags)
		Return AllocateRawEntry().Construct(Path, FrameCount, Flags)
	End
	
	Method AllocateEntry:ImageEntry(A:ImageEntry)
		Return AllocateRawEntry().Construct(A)
	End
	
	Method AllocateEntry:ImageEntry(Width:Int, Height:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags, Path:String="")
		Return AllocateRawEntry().Construct(Width, Height, FrameCount, Flags, Path)
	End
	
	Method AllocateEntry:ImageEntry(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags)
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

#If RESOURCES_ASYNC_ENABLED
Class AtlasImageManager Extends ImageManager Implements ImageReferenceManager, IOnLoadImageComplete
#Else
Class AtlasImageManager Extends ImageManager Implements ImageReferenceManager
#End
	' Constructor(s):
	
	' Calling up to the super-class's implementation is done through the standard 'ConstructManager' constructor:
	Method New(CreateContainer:Bool=True, BuildAtlasMap:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size, CallUpToSuperClass:Bool=Default_CallUpToSuperClass)
		' Call the main implementation.
		ConstructAtlasImageManager(CreateContainer, BuildAtlasMap, False, EntryPoolSize, CallUpToSuperClass)
	End
	
	Method New(Assets:AssetContainer<ImageEntry>, BuildAtlasMap:Bool=True, CopyData:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size, CallUpToSuperClass:Bool=Default_CallUpToSuperClass)
		' Call the main implementation.
		ConstructAtlasImageManager(Assets, BuildAtlasMap, False, CopyData, EntryPoolSize, CallUpToSuperClass)
	End
	
	#Rem
		This should be used for construction of this object through pools,
		or similar means. This constructor can be configured to not "call up"
		to 'ConstructManager', however, that is not recommended.
		
		Such behavior can be achieved through the 'CallUpToSuperClass' argument.
	#End
	
	Method ConstructAtlasImageManager:AtlasImageManager(CreateContainer:Bool=True, BuildAtlasMap:Bool=True, CareAboutPreviousAtlasMap:Bool=False, EntryPoolSize:Int=Default_EntryPool_Size, CallUpToSuperClass:Bool=Default_CallUpToSuperClass)
		If (CallUpToSuperClass) Then
			ConstructEntryManager(CreateContainer, EntryPoolSize)
		Endif
		
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
	
	Method ConstructAtlasImageManager:AtlasImageManager(Assets:AssetContainer<ImageEntry>, BuildAtlasMap:Bool=True, CareAboutPreviousAtlasMap:Bool=False, CopyData:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size, CallUpToSuperClass:Bool=Default_CallUpToSuperClass)
		If (CallUpToSuperClass) Then
			ConstructEntryManager(Assets, CopyData, EntryPoolSize)
		Endif
		
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
	Method LoadAutomaticSegment:ImageEntry(Path:String, X:Int=0, Y:Int=0, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, Callback:ImageEntryRecipient=Null, FrameWidth:Int=0, FrameHeight:Int=0, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
		Return LoadSegment(Path, X, Y, FrameWidth, FrameHeight, FrameCount, Flags, Callback, AddInternally, CareAboutInternalAdd)
	End
	
	' This command can be used to load a specific portion of an 'Image' object's surface.
	' Like the standard 'Load' commands, this will seamlessly work with the internal "atlas" map.
	Method LoadSegment:ImageEntry(Path:String, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, Callback:ImageEntryRecipient=Null, AddInternally:Bool=True, CareAboutInternalAdd:Bool=True)
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
		
		' Check if we have a call-back to work with:
		If (Callback <> Null) Then
			' Add the call-back specified to the newly generated entry.
			Entry.Add(Callback)
		Endif
		
		' Build the newly generated entry.
		BuildEntry(Entry)
		
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
	
	#If RESOURCES_ASYNC_ENABLED
		' Please refrain from using the 'Flags' argument(s) of these methods.
		Method GenerateAtlasAsync:Void(Entry:ImageEntry, Flags:Int=Image.DefaultFlags)
			#If RESOURCES_SAFE
				Entry.WaitingForAsynchronousReference = True
			#End
			
			GenerateAtlasAsync(Entry.Path, Flags)
			
			Return
		End
		
		Method GenerateAtlasAsync:Void(Path:String, Flags:Int=Image.DefaultFlags)
			GenerateAtlasAsync(Path, Self, Flags)
			
			Return
		End
		
		Method GenerateAtlasAsync:Void(Path:String, Callback:IOnLoadImageComplete, Flags:Int=Image.DefaultFlags)
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
		Local Atlas:= LoadImage(Path)
		
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
	Method AssignReference:Image(Entry:ImageEntry)
		Return AssignReference(Entry, True)
	End
	
	Method AssignReferenceAsync:Image(Entry:ImageEntry)
		Return AssignReferenceAsync(Entry, True)
	End
	
	Method AssignReference:Image(Entry:ImageEntry, CallUpOnFailure:Bool, X:Int=0, Y:Int=0)
		Return AssignReference(Entry, Entry.ShouldLoadFromDisk, CallUpOnFailure, X, Y)
	End
	
	Method AssignReference:Image(Entry:ImageEntry, Atlas:Image, CallUpOnFailure:Bool=True, X:Int=0, Y:Int=0)
		Return AssignReference(Entry, Entry.ShouldLoadFromDisk, Atlas, CallUpOnFailure, X, Y)
	End
	
	Method AssignReference:Image(Entry:ImageEntry, ShouldLoadFromDisk:Bool, CallUpOnFailure:Bool, X:Int=0, Y:Int=0)
		If (ShouldLoadFromDisk) Then
			'Local Atlas:= GenerateAtlas(Entry)
			
			Return AssignReference(Entry, ShouldLoadFromDisk, GenerateAtlas(Entry), CallUpOnFailure, X, Y) ' ShouldLoadFromDisk And (Atlas <> Null)
		Endif
		
		Return AssignReference(Entry, False, Null, CallUpOnFailure, X, Y)
	End
	
	Method AssignReference:Image(Entry:ImageEntry, ShouldLoadFromDisk:Bool, Atlas:Image, CallUpOnFailure:Bool=True, X:Int=0, Y:Int=0)
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
	
	Method AssignReferenceAsync:Image(Entry:ImageEntry, ShouldLoadFromDisk:Bool, CallUpOnFailure:Bool=True)
		#If RESOURCES_ASYNC_ENABLED
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
	#If RESOURCES_ASYNC_ENABLED
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

#If RESOURCES_ASYNC_ENABLED
Class ImageEntry Extends ManagedAssetEntry<Image, ImageReferenceManager, ImageEntryRecipient> Implements ImageReferenceManager, IOnLoadImageComplete
#Else
Class ImageEntry Extends ManagedAssetEntry<Image, ImageReferenceManager, ImageEntryRecipient> Implements ImageReferenceManager
#End
	' Constant variable(s):
	' Nothing so far.
	
	' Global variable(s):
	' Nothing so far.
	
	' Constructor(s) (Public):
	
	' These constructors exhibit the same behavior as their 'Construct' counterparts:
	Method New(Path:String="", FrameCount:Int=1, Flags:Int=Image.DefaultFlags, IsLinked:Bool=Default_IsLinked)
		Construct(Path, FrameCount, Flags, IsLinked)
	End
	
	Method New(Width:Int, Height:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, Path:String="", IsLinked:Bool=Default_IsLinked)
		' Call the main implementation.
		Construct(Width, Height, FrameCount, Flags, Path, IsLinked)
	End
	
	Method New(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags, IsLinked:Bool=Default_IsLinked)
		' Call the main implementation.
		Construct(Path, FrameWidth, FrameHeight, FrameCount, Flags, IsLinked)
	End
	
	Method New(Entry:ImageEntry, CopyReferenceData:Bool=Default_CopyReferenceData, CopyCallbackContainer:Bool=Default_CopyCallbackContainer)
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
	
	Method Construct:ImageEntry(Path:String="", FrameCount:Int=1, Flags:Int=Image.DefaultFlags, IsLinked:Bool=Default_IsLinked)
		Return Construct(Path, 0, 0, FrameCount, Flags, IsLinked)
	End
	
	Method Construct:ImageEntry(Width:Int, Height:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags, Path:String="", IsLinked:Bool=Default_IsLinked)
		Return Construct(Path, Width, Height, FrameCount, Flags, IsLinked)
	End
	
	Method Construct:ImageEntry(Path:String, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags, IsLinked:Bool=Default_IsLinked)
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
	
	Method ManagedGenerateReference:Image(Manager:ImageReferenceManager, DiscardExistingData:Bool=Default_DestroyReferenceData)
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
	
	Method ManagedGenerateReferenceAsync:Image(Manager:ImageReferenceManager, DiscardExistingData:Bool=Default_DestroyReferenceData)
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
		Self.Reference.Discard()
		Self.Reference = Null
		
		Return
	End
	
	Public
	
	' Methods (Public):
	Method AssignReference:Image(Entry:ImageEntry)
		Return Entry.AssignReference()
	End
	
	Method AssignReferenceAsync:Image(Entry:ImageEntry)
		Return Entry.AssignReferenceAsync()
	End
	
	Method AssignReference:Image()
		If (ShouldLoadFromDisk) Then
			If (FrameWidth > 0 And FrameHeight > 0) Then
				SetReference(LoadImage(Path, FrameWidth, FrameHeight, FrameCount, Flags))
			Else
				SetReference(LoadImage(Path, FrameCount, Flags))
			Endif
		Else
			SetReference(CreateImage(FrameWidth, FrameHeight, FrameCount, Flags))
		Endif
		
		If (Reference = Null) Then
			Throw New ImageNotFoundException(Self)
		Endif
		
		Return Reference
	End
	
	Method AssignReferenceAsync:Image()
		#If RESOURCES_ASYNC_ENABLED
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
	
	Method GetReference:Image()
		#If RESOURCES_SAFE
			If (WaitingForAsynchronousReference) Then
				#If CONFIG = "debug"
					DebugStop()
				#End
				
				' Throw an exception regarding the asynchronous state of the 'Reference' property.
				Throw New AsyncImageUnavailableException(Self)
				
				' Return, just in case.
				Return Null
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
		Endif
		
		SetReference(Atlas.GrabImage(X, Y, FrameWidth, FrameHeight, FrameCount, Flags))
		
		Return
	End
	
	#Rem
		These methods act as "grab" routines for the internal reference.
		
		These work as a standard "share operations", meaning
		image-data can't be explicitly discarded in the future.
		
		An 'Image' object will only be produced if the internal
		reference exists, and sharing can be done successfully.
		
		These methods do not make a formal calls to 'GetReference',
		meaning they are not implicitly capable of throwing access exceptions.
		
		The "grabbing" behavior of these methods is described by Mojo.
		Please keep in mind Mojo's behavior regarding multi-frame "grabbing".
	#End
	
	Method Grab:Image(X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags)
		' Check for errors:
		
		' Check if we have an internal reference to "grab" from:
		If (Self.Reference = Null) Then
			Return Null
		Endif
		
		#If RESOURCES_SAFE
			If (Self.FrameCount > 1) Then
				Return Null
			Endif
		#End
		
		' Make sure we can "share" the internal reference:
		If (Not Share()) Then
			Return Null
		Endif
		
		' Use Mojo to "grab" from the internal reference.
		Return Self.Reference.GrabImage(X, Y, FrameWidth, FrameHeight, FrameCount, Flags)
	End
	
	Method Grab:Image(X:Int=0, Y:Int=0)
		Return Grab(X, Y, Self.FrameWidth, Self.FrameHeight, Self.FrameCount, Self.Flags)
	End
	
	' This is used for "atlas" optimization purposes.
	' By default, 'ImageEntry' objects do not have positions.
	Method CheckPosition:Bool(X:Int=0, Y:Int=0)
		Return ((X = 0) And (Y = 0))
	End
	
	' Call-backs:
	#If RESOURCES_ASYNC_ENABLED
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
		If (CheckReference And (Self.Reference <> Input.Reference)) Then
			Return False
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
	
	Method Equals:Bool(Input_Reference:Image, Input_FrameCount:Int=1, Input_Flags:Int=Image.DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
		Return ((Self.Reference = Input_Reference) And Equals(Input_FrameWidth, Input_FrameHeight, Input_FrameCount, Input_Flags))
	End
	
	Method Equals:Bool(Input_Reference:Image, Input_Path:String="", Input_FrameCount:Int=1, Input_Flags:Int=Image.DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
		Return ((Self.Reference = Input_Reference) And Equals(Input_Path, Input_FrameCount, Input_Flags, Input_FrameWidth, Input_FrameHeight))
	End
	
	Method Equals:Bool(Input_Path:String, Input_FrameCount:Int=1, Input_Flags:Int=Image.DefaultFlags, Input_FrameWidth:Int=0, Input_FrameHeight:Int=0)
		Return ((Path = Input_Path) And Equals(Input_FrameWidth, Input_FrameHeight, Input_FrameCount, Input_Flags))
	End
	
	Method Equals:Bool(Input_FrameWidth:Int=0, Input_FrameHeight:Int=0, Input_FrameCount:Int=1, Input_Flags:Int=Image.DefaultFlags)
		Return Equals("", Input_FrameCount, Input_Flags, Input_FrameWidth, Input_FrameHeight) ' (FrameWidth = Input_FrameWidth And FrameHeight = Input_FrameHeight And FrameCount = Input_FrameCount And Flags = Input_Flags)
	End
	
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
	
	#If RESOURCES_SAFE
		Method IsReady:Bool() Property
			Return Super.IsReady() And Not WaitingForAsynchronousReference
		End
	#End

	' Fields (Public):
	Field Path:String
	
	Field FrameWidth:Int
	Field FrameHeight:Int
	Field FrameCount:Int
	
	Field Flags:Int
	
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
	Method New(Path:String="", FrameCount:Int=1, Flags:Int=Image.DefaultFlags, X:Int=0, Y:Int=0, IsLinked:Bool=Default_IsLinked, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Path, FrameCount, Flags, IsLinked)
		
		Self.X = X
		Self.Y = Y
		
		Self.CanBePooled = CanBePooled
	End
	
	Method New(Width:Int, Height:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, X:Int=0, Y:Int=0, Path:String="", IsLinked:Bool=Default_IsLinked, CanBePooled:Bool=Default_CanBePooled)
		' Call the super-class's implementation.
		Super.New(Width, Height, FrameCount, Flags, Path, IsLinked)
		
		Self.X = X
		Self.Y = Y
		
		Self.CanBePooled = CanBePooled
	End
	
	Method New(Path:String, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int, Flags:Int=Image.DefaultFlags, IsLinked:Bool=Default_IsLinked, CanBePooled:Bool=Default_CanBePooled)
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
		These implementations are especially useful For "sub-atlases".
	#End
	
	Method Grab:Image(X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags)
		Return Super.Grab(Self.X+X, Self.Y+Y, FrameWidth, FrameHeight, FrameCount, Flags)
	End
	
	Method Grab:Image(X:Int=0, Y:Int=0)
		Return Super.Grab(Self.X+X, Self.Y+Y)
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
	
	Method GrabFromAtlas:Image(AtlasManager:AtlasImageManager, X:Int, Y:Int, FrameWidth:Int, FrameHeight:Int, FrameCount:Int=1, Flags:Int=Image.DefaultFlags, CheckInternal:Bool=True, ForceAtlasCreation:Bool=False)
		' Check if we can use the standard implementation of 'Grab':
		If (CheckInternal And (Self.Reference <> Null And Self.Reference.Frames() = 1)) Then
			Return Grab(X, Y, FrameWidth, FrameHeight, FrameCount, Flags)
		Endif
		
		' Check for errors:
		If (AtlasManager = Null) Then
			Return Null
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
			Return Null
		Endif
		
		' We found an "atlas" to work with, "grab" a portion of it.
		Return Atlas.GrabImage(Self.X+X, Self.Y+Y, FrameWidth, FrameHeight, FrameCount, Flags)
	End
	
	Method CheckPosition:Bool(X:Int=0, Y:Int=0)
		Return (Self.X = X) And (Self.Y = Y)
	End
	
	' Properties:
	Method CanDeallocate:Bool() Property
		Return Self.CanBePooled And Super.CanDeallocate()
	End
	
	' Fields:
	Field X:Int, Y:Int
	
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