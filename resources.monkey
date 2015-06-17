Strict

Public

' Preprocessor related:
#If CONFIG = "debug"
	' If enabled, this tells this module to take
	' extra precautions for the sake of stability.
	#RESOURCES_SAFE = True
#End

#If BRL_GAMETARGET_IMPLEMENTED
	#RESOURCES_IMPORT_SOUND = True
	#RESOURCES_ASYNC_ENABLED = True
#End

' Imports:

' Standard image-management functionality.
Import image

' Standard sound-management functionality.
#If RESOURCES_IMPORT_SOUND
	Import sound
#End

' Standard resource-management functionality.
Import resourcemanager

' Mojo 2 functionality:
#If RESOURCES_MOJO2
	Import texture
#End