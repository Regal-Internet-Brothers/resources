Strict

Public

' Imports (Internal):
Import resources
Import assetentry
Import assetmanager

' Imports (External):

' BRL:
Import brl.pool

' Interfaces:
' Nothing so far.

' Classes:

#Rem
	DESCRIPTION:
		* This class provides shared functionality between "entry" based 'AssetManagers'.
	NOTES:
		* The 'EntryType' argument must be a class extending,
		or strictly following the 'AssetEntry' class.
	
		Support for non-standard entry-types (Not inheriting from 'AssetEntry')
		is not set in stone, and may be removed or otherwise broken.
		
		* Though the 'EntryType' argument must be based on the model proposed
		by 'AssetEntry', specific functionality (Such as destruction) may be assumed here (Rare).
#End

Class AssetEntryManager<EntryType> Extends AssetManager<EntryType> Abstract
	' Constant variable(s):
	
	' Defaults:
	Const Default_EntryPool_Size:Int = 8
	
	' Booleans / Flags:
	Const Default_CallUpToSuperClass:Bool = True
	
	' Constructor(s) (Public):
	Method New(CreateContainer:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(CreateContainer)
		
		Self.EntryPool = New Pool<EntryType>(EntryPoolSize)
	End
	
	' Please see the 'AddAssets' method's documentation for details on entry mutation.
	Method New(Assets:AssetContainer<EntryType>, CopyData:Bool=True, EntryPoolSize:Int=Default_EntryPool_Size)
		' Call the super-class's implementation.
		Super.New(Assets, CopyData)
		
		Self.EntryPool = New Pool<EntryType>(EntryPoolSize)
	End
	
	' Destructor(s):
	
	#Rem
		ATTENTION:
			* This command will not remove entries automatically.
			Because of this, it is recommended that you use
			'ClearContainer' after using this command.
			
			This will formally destruct all internally contained entries.
			
			* Linked entries can not be destructed formally. Because of this,
			they will need to be automatically handled by the garbage collector.
	#End
	
	Method FreeAssets:Bool()
		For Local E:= Eachin Container ' Self
			' Linked entries can not be deallocated properly,
			' make sure we don't deallocate linked/shared entries.
			If (Not E.IsLinked) Then
				DeallocateEntry(E)
			Endif
		Next
		
		' Return the default response.
		Return True
	End
	
	#Rem
	Method FreeManager:AssetManager<EntryType>(DestroyData:Bool=False)
		Self.EntryPool = Null
		
		' Call the super-class's implementation.
		Return Super.FreeManager(DestroyData)
	End
	#End
	
	' Methods (Public):
	
	' Though preferred, these are no different from 'AddAsset', and 'RemoveAsset':
	Method Add:Bool(Entry:EntryType)
		Return AddAsset(Entry)
	End
	
	Method Remove:Bool(Entry:EntryType)
		Return RemoveAsset(Entry)
	End
	
	#Rem
		The state of the 'Assets' object may not be changed by this command.
		However, the entries supplied may "self-mutate" themselves.
		This command follows standard sharing practice, meaning it
		will call the 'Share' method for each entry in 'Assets'.
		
		If 'RESOURCES_SAFE' is not enabled, entries that
		can not be "shared" properly will be added regardless.
	#End
	
	Method AddAssets:Bool(Assets:AssetManager<EntryType>)
		#If MOJOWRAPPER_ASSETMANAGER_STANDARDENUMERATION
			For Local Entry:= Eachin Assets ' Assets.Container
		#Else
			For Local Entry:= Eachin Assets.Container
		#End
				#If RESOURCES_SAFE
					If (Not ShareEntry(Entry)) Then
						' Continue to the next entry.
						Continue
					Endif
				#Else
					' Share the entry, even if it says otherwise.
					' To change this behavior, please enable
					' 'RESOURCES_SAFE' using the preprocessor.
					ShareEntry(Entry)
				#End
				
				' Add the "newly shared" entry.
				Add(Entry)
			Next
		
		' Return the default response.
		Return True
	End
	
	#Rem
		These implementations may not be sufficient; please follow your 'EntryType' type's guidelines.
		
		For example, you may be dealing with an 'EntryType' which supports "managed building"
		through external sources (Potentially supporting itself as a source).
	#End
	
	Method BuildEntry:Void(E:EntryType, DiscardExistingData:Bool=EntryType.Default_DestroyReferenceData)
		E.Build(DiscardExistingData)
		
		Return
	End
	
	Method BuildEntryManual:Void(E:EntryType, DiscardExistingData:Bool=EntryType.Default_DestroyReferenceData)
		E.BuildManual(DiscardExistingData)
		
		Return
	End
	
	Method BuildEntryAsync:Void(E:EntryType, DiscardExistingData:Bool=EntryType.Default_DestroyReferenceData)
		E.BuildAsync(DiscardExistingData)
		
		Return
	End
	
	#Rem
		This class defines deallocation, but not proper allocation.
		
		This is due to the nature of allocation, where
		specialized input is ideal for construction.
		
		Inheriting classes are expected to
		manage constructing entries themselves.
		
		This class provides basic allocation via 'AllocateRawEntry',
		but construction utilities are not provided.
	#End
	
	#Rem
		The 'AllocateRawEntry' command does not
		internally add the entry in question.
		
		Likewise, standalone allocation should not be tethered
		to this object, other than the internal pool the entry came from.
		
		To properly achieve this effect, please use the 'Add' command from another method.
		It is highly recommended that you deallocate entries after using them.
		
		Please do not deallocate shared/linked entries (See 'DeallocateEntry' for details).
	#End
	
	' This overload will not supply a properly constructed object.
	' To generate a properly constructed object, please
	' use the 'AllocateConstructedEntry' command.
	Method AllocateRawEntry:EntryType()
		' Allocate a new entry from the entry-pool.
		Return EntryPool.Allocate()
	End
	
	#Rem
		This command should always be called in order to destruct an 'EntryType'
		object that was produced by 'AllocateEntry', or similar commands.
		
		This command will "collect" the entry specified using an internal pool.
		This entry will then be potentially reused at any point.
		This command can be used regardless of the share/link state of the entry.
		
		It is not recommended that you pass shared/linked entries to this command.
		Such behavior is considered incorrect, and may or may not be resolved correctly.
		
		Entry management within this class already takes care of link/share checks.
		
		When inheriting from this class, it may be wise for you to write an implementation
		of 'DeallocateEntry' which "calls up" to this, passing a pre-destructed entry-object.
		
		If you plan on reimplementing this, it is wise to integrate controlled
		checks against 'CanDeallocate', as this implementation describes.
		
		Such checks would substitute for this implementation's checks, and consequently,
		the 'CheckDeallocationSafety' argument when calling implementation should be 'False'.
	#End
	
	Method DeallocateEntry:Bool(Entry:EntryType, CheckDeallocationSafety:Bool=True)
		#If RESOURCES_SAFE
			If (CheckDeallocationSafety) Then
				If (Not CanDeallocate(Entry)) Then
					Return False
				Endif
			Endif
		#End
		
		EntryPool.Free(Entry)
		
		' Return the default response.
		Return True
	End
	
	' Mutate the behavior of this command as you see fit.
	' It is recommended that you don't destruct shared/linked entries, however.
	' This implementation will take care of that for you.
	Method CanDeallocate:Bool(Entry:EntryType)
		If (Entry.IsLinked) Then
			#If CONFIG = "debug"
				DebugLog("Attempted to deallocate shared entry-object.")
			#End
			
			Return False
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method ShareEntry:Bool(Entry:EntryType)
		#If RESOURCES_SAFE
			If (Not Entry.Share()) Then
				#If CONFIG = "debug"
					DebugLog("Encountered un-linkable entry.")
					
					DebugStop()
				#End
				
				Return False
			Endif
			
			' Return the default response.
			Return True
		#Else
			Return Entry.Share()
		#End
	End
	
	' Methods (Private):
	Private
	
	' Nothing so far.
	
	Public
	
	' Properties:
	
	' This will provide the number of assets loaded.
	Method AssetsLoaded:Int() Property
		' Local variable(s):
		Local Assets:Int = 0
		
		For Local Entry:= Eachin Container ' Self
			If (Entry.IsReady()) Then
				Assets += 1
			Endif
		Next
		
		Return Assets
	End
	
	Method AssetsReady:Bool() Property
		For Local Entry:= Eachin Container ' Self
			If (Not Entry.IsReady()) Then
				Return False
			Endif
		Next
		
		' Return the default response.
		Return True
	End
	
	' Fields:
	Field EntryPool:Pool<EntryType>
End