/*

Copyright (c) 2010 TMS International B.V.
All rights reserved.

WARNING: Please use the copy of this file which can be found on the Driver CD 
which was included with your TMSi frontend.

*/
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <Windows.h>

#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include <conio.h>
#include <tchar.h> 
#include <time.h>
#include <assert.h>
#include <share.h>

#include "TmsiSDK.h" 

#define LENGTH_PRINTSTRING 1024

// Function pointer to use with SDK library
static POPEN fpOpen;
static PCLOSE fpClose; 
static PSTART fpStart;
static PSTOP fpStop;	
static PSETSIGNALBUFFER fpSetSignalBuffer;
static PGETSAMPLES	fpGetSamples;
static PGETSIGNALFORMAT fpGetSignalFormat; 
static PFREE fpFree;
static PLIBRARYINIT fpLibraryInit;
static PLIBRARYEXIT fpLibraryExit;
static PGETFRONTENDINFO fpGetFrontEndInfo;
static PSETRTCTIME fpSetRtcTime;
static PGETRTCTIME fpGetRtcTime;
static PSETRTCALARMTIME fpSetRtcAlarmTime;
static PGETRTCALARMTIME fpGetRtcAlarmTime;
static PGETERRORCODE fpGetErrorCode;
static PGETERRORCODEMESSAGE fpGetErrorCodeMessage;
static PFREEDEVICELIST fpFreeDeviceList;
static PGETDEVICELIST fpGetDeviceList;
static PGETCONNECTIONPROPERTIES fpGetConnectionProperties;
static PSETMEASURINGMODE fpSetMeasuringMode;
static PSETREFCALCULATION fpSetRefCalculation;
static PGETBUFFERINFO fpGetBufferInfo;

// Functions for Mobita
static PSTARTCARDFILE fpStartCardFile;
static PSTOPCARDFILE fpStopCardFile;
static PGETCARDFILESAMPLES fpGetCardFileSamples;
static PGETCARDFILESIGNALFORMAT fpGetCardFileSignalFormat;
static POPENCARDFILE fpOpenCardFile;
static PGETCARDFILELIST fpGetCardFileList;
static PCLOSECARDFILE fpCloseCardFile;
static PGETRECORDINGCONFIGURATION fpGetRecordingConfiguration;
static PSETRECORDINGCONFIGURATION fpSetRecordingConfiguration;
static PGETEXTFRONTENDINFO fpGetExtFrontEndInfo;

//Functions for Nexus10-MKII
static PGETRANDOMKEY fpGetRandomKey;
static PUNLOCKFRONTEND fpUnlockFrontEnd;
static PGETOEMSIZE fpGetOEMSize;
static PSETOEMDATA fpSetOEMData;
static PGETOEMDATA fpGetOEMData;
static PSETSTORAGEMODE fpSetStorageMode;

static PGETDIGSENSORDATA fpGetDigSensorData;
static PSETDIGSENSORDATA fpSetDigSensorData;

// Functions for Nexus
static PGETFLASHSTATUS fpGetFlashStatus;
static PSTARTFLASHDATA fpStartFlashData;
static PGETFLASHSAMPLES fpGetFlashSamples;
static PSTOPFLASHDATA fpStopFlashData;
static PFLASHERASEMEMORY fpFlashEraseMemory;
static PSETFLASHDATA fpSetFlashData;

// Functions for EPU
static PSETCHANNELREFERENCESWITCH fpSetChannelReferenceSwitch;


static POPENFIRSTDEVICE fpOpenFirstDevice;

static char PrintString[LENGTH_PRINTSTRING];

static FILE *fp = 0 ;

static void AppExit(int Param)
{
 	exit(Param);
}

static void PrintFunction( const char* funcname, const char *result )
{
#define LOG_WRITE_MODE "wb"		/*!< File is writeable and contains binary data */
	const char filenamedev[] = "tmsi_example.log";

	if( fp == NULL )
	{
		fp = _fsopen( filenamedev, LOG_WRITE_MODE, _SH_DENYNO  );

		if( fp == NULL )
		{
			printf( "Can not open [%s] file in this directory\n", filenamedev );
			fp=NULL;
		}
		else
		{
			fprintf( fp, "%s %s\r\n", __FUNCTION__, __DATE__ );
		}
	}

	// Print to screen
	printf( "%s : %s\n", funcname, result );

	// Print to file if the file is open
	if (fp != NULL )
	{		
		SYSTEMTIME Time;
		GetLocalTime( &Time );

		fprintf( fp, "%02u,%02u,%02u,%02u,%03u,%s,%s\r\n", Time.wDay, Time.wHour, Time.wMinute, Time.wSecond, Time.wMilliseconds, funcname, result );
		fflush(fp);
	}
}

#define TRACEACTION(result) PrintFunction( __FUNCTION__, result )


static int FindSawChannel( SIGNAL_FORMAT *psf )
{
	int i;
	int SawChannel, DigiChannel;

	SawChannel = DigiChannel = -1 ;
	for( i = 0 ; i < (int) psf->Elements ; i++ ) 
	{	
		if( psf[i].Type == CHANNELTYPE_SAW )
		{
			SawChannel = i ;
		}

		if( psf[i].Type == CHANNELTYPE_DIG )
		{
			DigiChannel = i ;
		}
	}

	if( SawChannel > -1 )
		return SawChannel ;

	if( DigiChannel  > -1 )
		return DigiChannel ;

	return psf->Elements-1 ;
}

static int FindDigiChannel( SIGNAL_FORMAT *psf )
{
	int i;
	int DigiChannel;

	DigiChannel = -1 ;
	for( i = 0 ; i < (int) psf->Elements ; i++ ) 
	{	
		if( psf[i].Type == CHANNELTYPE_DIG )
		{
			DigiChannel = i ;
		}
	}

	if( DigiChannel  > -1 )
		return DigiChannel ;

	return psf->Elements-2 ;
}

static void PrintChannelInformation( SIGNAL_FORMAT *psf )
{
	int i,j;
	char ChannelInformation[MAX_PATH];

	for( i = 0 ; i < (int) psf->Elements ; i++ ) 
	{	
		for(j=0 ; j<SIGNAL_NAME; j++ )
			PrintString[j] = (char) psf[i].Name[j];

		sprintf_s( ChannelInformation, MAX_PATH, "%3d: %s Format %d Type %d Bytes %d Subtype %d UnitId %d UnitExponent %d",
			i,PrintString,psf[i].Format,psf[i].Type, psf[i].Bytes, psf[i].SubType, 
			psf[i].UnitId, psf[i].UnitExponent ); 

		TRACEACTION( ChannelInformation );
	}
}

static void PrintChannelTypeInformation( SIGNAL_FORMAT *psf )
{
	int i,j;
	char ChannelTypeName[MAX_PATH];
	char ChannelUnitName[MAX_PATH];
	char const *ChannelValueType = NULL ;
	char unitnames[][3] = { "y", "z", "a", "f", "p", "n", "u", "m", "c", "d", "da", "h", "k", "M", "G", "T", "P", "E", "Z", "Y" };
	int unitexponents[] = { -24,-21,-18,-15,-12,-9,-6,-3,-2,-1,1,2,3,6,9,12,15,18,21,24 };

	for( i = 0 ; i < (int) psf->Elements ; i++ ) 
	{	
		int unitexp = psf[i].UnitExponent;
		ChannelUnitName[0] = 0;
		ChannelTypeName[0] = 0;

		// Determine channel unit name
		switch( psf[i].UnitId )
		{
		case UNIT_UNKNOWN :
			// No unit shown
			break;
		case UNIT_VOLT:

			for( j=0; j < sizeof(unitexponents)/sizeof(unitexponents[0]); j++ )
			{
				if( unitexp == unitexponents[j] )
				{
					strcpy_s( ChannelUnitName, MAX_PATH, unitnames[j] );
					break;
				}
			}   
			strcat_s( ChannelUnitName, MAX_PATH, "V" );
			break;
		case UNIT_PERCENT:
			strcpy_s( ChannelUnitName, MAX_PATH, "%%");
			break;
		case UNIT_BPM:
			strcpy_s( ChannelUnitName, MAX_PATH, "BPM");
			break;
		case UNIT_BAR:
			strcpy_s( ChannelUnitName, MAX_PATH, "BAR");
			break;
		case UNIT_PSI:
			strcpy_s( ChannelUnitName, MAX_PATH, "PSI");
			break;
		case UNIT_MH20:
			strcpy_s( ChannelUnitName, MAX_PATH, "mH2O");
			break;
		case UNIT_MHG:
			strcpy_s( ChannelUnitName, MAX_PATH, "mHG");
			break;
		case UNIT_BIT:
			strcpy_s( ChannelUnitName, MAX_PATH, "BIT" );
			break;
		case UNIT_GRAVITY:
			strcpy_s( ChannelUnitName, MAX_PATH, "g" );
			break;
		default:
			strcpy_s( ChannelUnitName, MAX_PATH, "?" );
			break;
		}

		// Determine channel type
		switch( psf[i].Type )
		{
		case CHANNELTYPE_EXG:
			strcpy_s( ChannelTypeName, MAX_PATH, "EXG" );
			break;
		case CHANNELTYPE_BIP:
			strcpy_s( ChannelTypeName, MAX_PATH, "BIP");
			break;
		case CHANNELTYPE_AUX:
			strcpy_s( ChannelTypeName, MAX_PATH, "AUX");
			break;
		case CHANNELTYPE_DIG:
			strcpy_s( ChannelTypeName, MAX_PATH, "DIG");
			break;
		case CHANNELTYPE_TIME:
			strcpy_s( ChannelTypeName, MAX_PATH, "TIME");
			break;
		case CHANNELTYPE_LEAK:
			strcpy_s( ChannelTypeName, MAX_PATH, "LEAK");
			break;
		case CHANNELTYPE_PRESSURE:
			strcpy_s( ChannelTypeName, MAX_PATH, "PRESSURE");
			break;
		case CHANNELTYPE_ENVELOPE:
			strcpy_s( ChannelTypeName, MAX_PATH, "ENVELOPE");
			break;
		case CHANNELTYPE_MARKER:
			strcpy_s( ChannelTypeName, MAX_PATH, "MARKER");
			break;
		case CHANNELTYPE_SAW:
			strcpy_s( ChannelTypeName, MAX_PATH, "SAW");
			break;
		case CHANNELTYPE_SAO2:
			strcpy_s( ChannelTypeName, MAX_PATH, "SAO2");
			break;
		case CHANNELTYPE_ACCEL:
			strcpy_s( ChannelTypeName, MAX_PATH, "ACCEL");
			break;
		default:
			strcpy_s( ChannelTypeName, MAX_PATH, "?");
			break;
		}

		switch( psf[i].Format )
		{
		case SF_INTEGER   : ChannelValueType = "signed integer" ; break ;
		case SF_UNSIGNED  : ChannelValueType = "unsigned integer" ; break ;
		default : ChannelValueType = "unknown" ; break ;
		}

		sprintf_s( PrintString, MAX_PATH, "%3d: %s %s %s", i, ChannelTypeName, ChannelUnitName, ChannelValueType ); 
sprintf_s( PrintString, MAX_PATH, "%3d: %s %s %s UG %.4lf UO %.4lf", i, ChannelTypeName, ChannelUnitName, ChannelValueType, psf[i].UnitGain, psf[i].UnitOffSet ); 
		
		TRACEACTION( PrintString );
	}
}

static void DisplaySysTime( const SYSTEMTIME *Time )
{
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Weekday %d on %d-%d-%d Time %d:%d:%d", 
		Time->wDayOfWeek, Time->wDay, Time->wMonth, Time->wYear, 
		Time->wHour, Time->wMinute, Time->wSecond  );
	TRACEACTION( PrintString );
}

static void DisplayAlarmSysTime( const SYSTEMTIME *Time, char AlarmOnOff )
{
	char const *AlarmOn = "Alarm On";
	char const *AlarmOff = "Alarm Off";
	char const *AlarmState = AlarmOff ;

	if( AlarmOnOff )
		AlarmState = AlarmOn ;

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Day %d on time %d:%d:%d %s", 
		Time->wDay, 
		Time->wHour, Time->wMinute, Time->wSecond, AlarmState );
	TRACEACTION( PrintString );
}

static void SetWifiOn( void *Handle )
{
	int Status;
	int ErrorCode;
	TMSiRecordingConfigType APISchedule;

	// Init
	memset( &APISchedule, 0, sizeof(APISchedule)); // Set all fields of the structure to zero

	// This combination will only turn on wifi, no recording, see frontend user manual
	APISchedule.StartControl = (TMSiStartControlType) (sc_rf_auto_start);

	TRACEACTION( "Try to SetRecordingConfiguration" );
	Status = fpSetRecordingConfiguration( Handle, &APISchedule, NULL, 0 );
	if( Status )
	{
		TRACEACTION( "SetRecordingConfiguration success" );
	}
	else
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Error SetRecordingConfiguration, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}
}


static void SetRecordingSchedule( void *Handle, WORD MinutesOfOffset, WORD TimeToMeasure )
{
	int Status;
	int ErrorCode;
	TMSiRecordingConfigType APISchedule;
	SYSTEMTIME Time; 
	BOOLEAN AlarmOnOff;

	TRACEACTION( "Try to set the alarm time");
	GetLocalTime( &Time );
	Time.wHour += (Time.wMinute+MinutesOfOffset) / 60 ;
	Time.wMinute = (Time.wMinute+MinutesOfOffset) % 60 ;
	AlarmOnOff = 1 ;
	Status = fpSetRtcAlarmTime( Handle, &Time, AlarmOnOff );
	if( Status )
	{
		TRACEACTION( "Alarm Time set");
		DisplayAlarmSysTime( &Time, AlarmOnOff );
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "SetRtcAlarmTime failed, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	// Next calls in this function are for Mobita
	Status = fpGetRecordingConfiguration( Handle, &APISchedule, NULL, 0 );
	if( Status )
	{
		TRACEACTION( "GetRecordingConfiguration success");
	}
	else
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Error GetRecordingConfiguration, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );

		// When there is no valid schedule just continue, else return
		if( ErrorCode != 0x1E )
			return ;
	}

	// Set a recoding schedule for the internal storage
	// 2 minute recording, repeat 2 times, with 1 minute interval
	memset( &APISchedule, 0, sizeof(APISchedule)); // Set all fields of the structure to zero

	// This combination will lead to an error, see frontend user manual
	APISchedule.StartControl = (TMSiStartControlType) (sc_rtc_set | sc_alarm_record_auto_start );

	// This combination will also lead to an error, see frontend user manual
	APISchedule.StartControl = (TMSiStartControlType) (sc_alarm_record_auto_start  | sc_power_on_record_auto_start );

	// This combination will lead to an recurring recording , see frontend user manual
	APISchedule.StartControl = (TMSiStartControlType) (sc_power_on_record_auto_start );

	// This combination will lead to an recording wich is started and stopped over wifi, see frontend user manual
	// Keep in mind that the samplerate over wifi must be the same as the samplerate on the card
	APISchedule.StartControl = (TMSiStartControlType) (sc_man_record_enable | sc_rf_auto_start );

	// Set the RecordingSampleRate to the basesamerate from the frontendinfo
	APISchedule.RecordingSampleRate = 2000;

	if( MinutesOfOffset == 0 )
	{
		TRACEACTION( "Create RecordingConfiguration for manual recording" );

		// This combination will lead to an recording wich is started and stopped by putting the header on
		APISchedule.StartControl = (TMSiStartControlType) sc_power_on_record_auto_start;
		strncpy_s( APISchedule.MeasureFileName, MAX_MEASUREFILENAME_LENGTH, "MANREC1", 8 );
	}
	else
	{
		TRACEACTION( "Create RecordingConfiguration for timed recording" );

		// This combination will lead to an recurring recording , see frontend user manual
		APISchedule.StartControl = (TMSiStartControlType) (sc_alarm_record_auto_start  | sc_alarm_recurring );

		GetLocalTime( &APISchedule.AlarmTimeStart );
		GetLocalTime( &APISchedule.RFInterfStartTime );	
		GetLocalTime( &APISchedule.AlarmTimeStop );
		GetLocalTime( &APISchedule.RFInterfStopTime );	

		APISchedule.AlarmTimeStart.wMinute += 1+MinutesOfOffset ; // Start at least at now+1 minutes + user offset
		if( APISchedule.AlarmTimeStart.wMinute > 59 )
		{
			APISchedule.AlarmTimeStart.wMinute -= 60 ;
			APISchedule.AlarmTimeStart.wHour += 1 ;
		}
		APISchedule.AlarmTimeStop.wMinute = APISchedule.AlarmTimeStart.wMinute+ TimeToMeasure ; // End desired minutes after start
		if( APISchedule.AlarmTimeStop.wMinute > 59 )
		{
			APISchedule.AlarmTimeStop.wMinute -= 60 ;
			APISchedule.AlarmTimeStop.wHour += 1 ;
		}
		APISchedule.AlarmTimeInterval.wHour = 1 ; // repeat every hour
		APISchedule.AlarmTimeCount = 2 ; // repetition is 2

		strncpy_s( APISchedule.MeasureFileName, MAX_MEASUREFILENAME_LENGTH, "TIMREC1", 8 );
	}

	strncpy_s( APISchedule.UserString1, MAX_USERSTRING_LENGTH, "ExampleCode", 12 );
	strncpy_s( APISchedule.PatientID, MAX_PATIENTID_LENGTH, "PATIENT1", 9 );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "APISchedule.StartControl = %d", APISchedule.StartControl );
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "APISchedule.AlarmTimeStart.wMinute = %d", APISchedule.AlarmTimeStart.wMinute);
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "APISchedule.AlarmTimeStop.wMinute = %d", APISchedule.AlarmTimeStop.wMinute);
	TRACEACTION( PrintString );

	TRACEACTION( "Try to SetRecordingConfiguration" );
	Status = fpSetRecordingConfiguration( Handle, &APISchedule, NULL, 0 );
	if( Status )
	{
		TRACEACTION( "SetRecordingConfiguration success" );
	}
	else
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Error SetRecordingConfiguration, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}
}

static void GetRecordingSchedule( void *Handle )
{
	int Status;
	int ErrorCode;
	SYSTEMTIME Time; 
	BOOLEAN AlarmOnOff;
	TMSiRecordingConfigType APISchedule;

	TRACEACTION( "Try to get the alarm time");
	Status = fpGetRtcAlarmTime( Handle, &Time, &AlarmOnOff );
	if( Status == 1 )
	{
		TRACEACTION( "Alarm Time get");
		DisplayAlarmSysTime( &Time, AlarmOnOff );
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not get alarm time, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	// Next calls in this function are for Mobita
	Status = fpGetRecordingConfiguration( Handle, &APISchedule, NULL, 0 );
	if( Status == 0 )
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Error getting storage schedule, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		fpLibraryExit( Handle );
		AppExit(1);
	}

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "FrontEndAdpSN %d", APISchedule.FrontEndAdpSN);
	TRACEACTION( PrintString );
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "FrontEndSN %d", APISchedule.FrontEndSN);
	TRACEACTION( PrintString );
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "RecordingSampleRate %d", APISchedule.RecordingSampleRate );
	TRACEACTION( PrintString );
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "AlarmTimeCount %d", APISchedule.AlarmTimeCount );
	TRACEACTION( PrintString );
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "StartControl 0x%x", APISchedule.StartControl );
	TRACEACTION( PrintString );

	TRACEACTION("==== Bitwise settings of StartControl ====");
	if( APISchedule.StartControl & sc_man_shutdown_enable )
		TRACEACTION( "sc_man_shutdown_enable " );

	if( APISchedule.StartControl & sc_rf_recurring )
		TRACEACTION( "sc_rf_recurring " );

	if( APISchedule.StartControl & sc_rf_timed_start )
		TRACEACTION( "sc_rf_timed_start " );

	if( APISchedule.StartControl & sc_rf_auto_start )
		TRACEACTION( "sc_rf_auto_start " );

	if( APISchedule.StartControl & sc_alarm_recurring )
		TRACEACTION( "sc_alarm_recurring " );

	if( APISchedule.StartControl & sc_power_on_record_auto_start )
		TRACEACTION( "sc_power_on_record_auto_start " );

	if( APISchedule.StartControl & sc_man_record_enable )
		TRACEACTION( "sc_man_record_enable " );

	if( APISchedule.StartControl & sc_alarm_record_auto_start )
		TRACEACTION( "sc_alarm_record_auto_start " );

	if( APISchedule.StartControl & sc_rtc_set )
		TRACEACTION( "sc_rtc_set " );

	TRACEACTION("==== ====");

	DisplaySysTime( &APISchedule.AlarmTimeStart );
	DisplaySysTime( &APISchedule.AlarmTimeStop );
	DisplaySysTime( &APISchedule.AlarmTimeInterval );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "RFInterfCount %d", APISchedule.RFInterfCount );
	TRACEACTION( PrintString );
	DisplaySysTime( &APISchedule.RFInterfStartTime );
	DisplaySysTime( &APISchedule.RFInterfStopTime );
	DisplaySysTime( &APISchedule.RFInterfInterval );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "MeasureFileName %s", APISchedule.MeasureFileName );
	TRACEACTION( PrintString );
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "UserString1 %s", APISchedule.UserString1 );
	TRACEACTION( PrintString );
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "PatientID %s", APISchedule.PatientID );
	TRACEACTION( PrintString );
}

static void PrintSaw( unsigned int TotalNrSamples, int ShowChannel, unsigned int *SignalBuffer, int NrSamples )
{
printf("\rSC %u [%3d]=0x%x #%d ", TotalNrSamples, ShowChannel,SignalBuffer[ShowChannel], NrSamples );
}

static void GetSampleDataWhileMeasuring( void* Handle, unsigned int WhishedLoops, unsigned int ExpectedSawDifference, 
	unsigned int ExpectedSawMask, unsigned int DesiredSampleMinutes, int DesiredSampleRate )
{
	ULONG SampleRateInMilliHz, SampleRateInHz ;
	ULONG SignalBufferSizeInSamples;
	unsigned int BytesPerSample;
	int BytesReturned;
	int i;
	int NumberOfChannels = 0;
	PSIGNAL_FORMAT psf = NULL;
	SYSTEMTIME Time = {0};
	BOOLEAN Status;
	char FrontEndName[MAX_FRONTENDNAME_LENGTH];
	unsigned int *SignalBuffer, SignalBufferSizeInBytes ;
	int ErrorCode;
	unsigned int StartNr;
	unsigned int LastSaw;
	unsigned int SignalStrength, NrOfCRCErrors, NrOfSampleBlocks;
	unsigned int Jumps=0;
	unsigned int JumpsSaw=0;
	float *Fval;
	ULONG Overflow, PercentFull ;
	unsigned int CurrentSaw=0 ;

#ifdef SAVE_SAMPLES	
	int k;
	FILE *ascf = fopen( "samples.txt", "w" );
#endif

	TRACEACTION( "Try to call GetSignalFormat");

	psf = fpGetSignalFormat( Handle, FrontEndName ); 

	if( psf != NULL ) 
	{	
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "FrontEndName = [%s]", FrontEndName );
		TRACEACTION( PrintString );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "NumberOfChannels = %d", psf->Elements );
		TRACEACTION( PrintString );

		NumberOfChannels = psf->Elements ;
		PrintChannelInformation( psf );
		PrintChannelTypeInformation( psf );
	}	
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not get SignalFormat, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		AppExit(1);
	}

	// All channels are always 4 bytes, so just multiply by the nr of channels
	BytesPerSample = NumberOfChannels * sizeof(long);

	if( BytesPerSample == 0 ) 
	{	
		TRACEACTION( "BytesPerSample == 0" );
		AppExit(1); 
	}
	
	SampleRateInMilliHz = MAX_SAMPLE_RATE;
	SignalBufferSizeInSamples = MAX_BUFFER_SIZE;

	TRACEACTION( "Find the maximal samplerate");
	if( fpSetSignalBuffer( Handle, &SampleRateInMilliHz,&SignalBufferSizeInSamples) != TRUE )
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "SetSignalBuffer 1 failed, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		AppExit(1);
	}

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Maximum sample rate = %d Hz",SampleRateInMilliHz  / 1000 );
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Maximum Buffer size = %d Samples", SignalBufferSizeInSamples);
	TRACEACTION( PrintString );

	// Set the samplerate in Herz
	if( DesiredSampleRate > 0 )
		SampleRateInMilliHz = 1000*DesiredSampleRate ;

	SignalBufferSizeInSamples = 10*SampleRateInMilliHz/1000 ;
	Status = FALSE ;

	do 
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Set the selected samplerate = %d Hz", SampleRateInMilliHz  / 1000 );
		TRACEACTION( PrintString );

		Status = fpSetSignalBuffer( Handle, &SampleRateInMilliHz,&SignalBufferSizeInSamples);

		if( Status == FALSE )
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "SetSignalBuffer 2 failed, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );

			if( ErrorCode == 0x19 )
			{
				// selected sample frequency out of range for this communication method
				SampleRateInMilliHz /= 2 ;
			}
			else
			{
				// can not fix this here, so return and stop
				return ;
			}
		}

	} while ( Status == FALSE );

	SampleRateInHz = SampleRateInMilliHz / 1000 ;

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Selected sample rate = %d Hz",SampleRateInMilliHz  / 1000 );
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Selected Buffer size = %d Samples", SignalBufferSizeInSamples);
	TRACEACTION( PrintString );

	// We know now the NumberOfChannels and the choosen SampleRateInHz, so allocate now the Signalbuffer
	SignalBufferSizeInBytes = SignalBufferSizeInSamples * NumberOfChannels * sizeof(SignalBuffer[0]);
	SignalBuffer = (unsigned int*) malloc( SignalBufferSizeInBytes );

	if( SignalBuffer == NULL )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not allocate %d bytes of memory for GetSamples buffer", 
			SignalBufferSizeInBytes );
		TRACEACTION( PrintString );
		AppExit(1); 
	}

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Allocated %d bytes of memory for GetSamples buffer", 
		SignalBufferSizeInBytes );
	TRACEACTION( PrintString );

	Fval = (float*) malloc( NumberOfChannels * sizeof(Fval[0]));

	if( Fval == NULL )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not allocate %d bytes of memory for Fval", 
			SignalBufferSizeInBytes );
		TRACEACTION( PrintString );
		AppExit(1); 
	}

	Status = fpGetConnectionProperties( Handle, &SignalStrength, &NrOfCRCErrors, &NrOfSampleBlocks );
	if( Status == 0 )
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "fpGetConnectionProperties failed, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		AppExit(1);
	}
	else
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, 
			"fpGetConnectionProperties SignalStrength %d NrOfCRCErrors %d NrOfSampleBlocks %d", 
			SignalStrength, NrOfCRCErrors, NrOfSampleBlocks);
		TRACEACTION( PrintString );
	}

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "ExpectedSawDifference 0x%x ExpectedSawMask 0x%x", ExpectedSawDifference, ExpectedSawMask );
	TRACEACTION( PrintString );

	for( StartNr = 0 ; StartNr < WhishedLoops ; StartNr++ )
	{
		const int ShowChannel = FindSawChannel( psf );
		unsigned int Total=0; 
		int SCTotal=0, SCHits=0, SCMin=10000, SCMax=0;
		unsigned int NoDataRecieved=0;
		unsigned int TotalNrSamples=0;

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Start try loop =  %d for %d minutes", StartNr, DesiredSampleMinutes );
		TRACEACTION( PrintString );

		GetLocalTime( &Time );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Start Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );
		TRACEACTION( PrintString );

		LastSaw=0;
		if( fpStart( Handle) )
		{	
			unsigned int DesiredSamples = SampleRateInHz * DesiredSampleMinutes * 60 ;
			TotalNrSamples=0;

			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Sampling started, printing channel %d", ShowChannel );
			TRACEACTION( PrintString );
			while(TotalNrSamples < DesiredSamples )
			{			
				// if there is data available get samples from the device
				// GetSamples returns the number of bytes written in the signal buffer
				// This will always be a multiple op BytesPerSample. 
				// Divide the result by BytesPerSamples to get the number of samples returned

				BytesReturned = fpGetSamples(Handle, (PULONG) SignalBuffer, SignalBufferSizeInBytes );
				if( BytesReturned > 0) 
				{	
					const int NrSamples = BytesReturned/(NumberOfChannels*sizeof(unsigned int));
					
					GetLocalTime( &Time );

					SCTotal += NrSamples ;
					SCHits++ ;
					if( NrSamples > SCMax )
						SCMax = NrSamples ;

					if( NrSamples < SCMin )
						SCMin = NrSamples ;

					NoDataRecieved=0;
					Total += BytesReturned;

#define USE_RAW_INT
#ifdef USE_RAW_INT
					// Print the raw integers as delivered by the GetSamples call
					TotalNrSamples+=NrSamples;
					PrintSaw( TotalNrSamples, ShowChannel, SignalBuffer, NrSamples );
#else
					for(i=0 ; i<NumberOfChannels ; i++ )
					{
						// For overflow of a analog channel, set the value to zero 
						if( SignalBuffer[i] == OVERFLOW_32BITS && 
							(psf[i].Type == CHANNELTYPE_EXG || 
							psf[i].Type == CHANNELTYPE_BIP || 
							psf[i].Type == CHANNELTYPE_AUX ))
						{
							Fval[i] = 0 ; // Set it to a value you find a good sign of a overflow
						}
						else
						{
							switch( psf[i].Format )
							{
							case SF_UNSIGNED  : // unsigned integer
								Fval[i] = SignalBuffer[i] *  psf[i].UnitGain +  psf[i].UnitOffSet ;
								break ;
							case SF_INTEGER: // signed integer
								Fval[i] = ((int) SignalBuffer[i]) *  psf[i].UnitGain +  psf[i].UnitOffSet ;
								break ;
							default : 
								Fval[i] = 0 ; // For unknown types, set the value to zero 
								break ;
							}
						}
					}
					// Print the cooked floats, which are calculated from 
					// the raw integers as delivered by the GetSamples and
					// the channel information from GetSignalFormat
					printf("\rSC %d %.0f %.0f %.0f 0x%x #%d ", Total / BytesPerSample, 
						Fval[0], Fval[1], Fval[2], SignalBuffer[ShowChannel],
						NrSamples );
#endif

					for(i=0 ; i< NrSamples ; i++ )
					{
						unsigned int ActualSawDifference;
						const int SawIndex = i*NumberOfChannels + ShowChannel ;
						const unsigned int RawValue =(unsigned int) SignalBuffer[SawIndex];

						CurrentSaw = RawValue ;
						ActualSawDifference = (CurrentSaw - LastSaw) & ExpectedSawMask;

						if( ActualSawDifference != ExpectedSawDifference && ActualSawDifference != 0x0 ) 
						{
							Jumps++ ;
							JumpsSaw += ActualSawDifference ;
							sprintf_s( PrintString, LENGTH_PRINTSTRING, "\rSC %d DIFF [%u]=0x%x (0x%x)                          ", TotalNrSamples, SawIndex, CurrentSaw, LastSaw );
							TRACEACTION( PrintString );	
						}

						LastSaw = CurrentSaw ;
#ifdef SAVE_SAMPLES
						for(k=0 ; k<NumberOfChannels ; k++ )
							fprintf( ascf, "0x%x ", SignalBuffer[k+i*NumberOfChannels] );
						fprintf( ascf, "\n");
#endif
					}
				}
				else 
				{
					if( BytesReturned == 0 )
					{
						Status = fpGetBufferInfo( Handle, &Overflow, &PercentFull );

						if( Status != 0 && Overflow > 0 && PercentFull > 0 )
						{
							sprintf_s( PrintString, LENGTH_PRINTSTRING, "Overflow %d PercentFull %d", Overflow, PercentFull );
							TRACEACTION( PrintString );
						}

						//allow other applications some extra process time 
						Sleep(10);
						NoDataRecieved++ ;

						// Rough estimate how many times you don't get samples
						if( NoDataRecieved > 100000 )
						{
							// Several time no data recieved
							// Stop sampling now, jump out of the while loop
							//
							DesiredSampleMinutes = 0 ;	
							ErrorCode = fpGetErrorCode(Handle);
							sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to get data, errorcode = %d (%s)", 
								ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
							TRACEACTION( PrintString );
						}
					}
					else
					{
						// Negative value returned, so there is a problem.
						// Stop sampling now, jump out of the while loop
						DesiredSampleMinutes = 0 ;
						sprintf_s( PrintString, LENGTH_PRINTSTRING,"Last Sample Min %d Sec %d mSec %d", Time.wMinute, Time.wSecond, Time.wMilliseconds );
						TRACEACTION( PrintString );
						GetLocalTime( &Time );
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Negative return at Min %d Sec %d mSec %d", Time.wMinute, Time.wSecond, Time.wMilliseconds );			
						TRACEACTION( PrintString );	
	
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Negative return from GetSampleDataWhileMeasuring after %d samples, errorcode = %d (%s)", 
							TotalNrSamples, BytesReturned, fpGetErrorCodeMessage(Handle,BytesReturned) );
						TRACEACTION( PrintString );
						
						ErrorCode = fpGetErrorCode(Handle);
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Errorcode = %d (%s)", ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
						TRACEACTION( PrintString );

						// Stop the loop
						DesiredSamples=0;
					}
				}
			}
		}
		else 
		{	
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to start the Device, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		Status = fpGetBufferInfo( Handle, &Overflow, &PercentFull );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Before Stop : Overflow %d PercentFull %d", Overflow, PercentFull );
			TRACEACTION( PrintString );
		}
		else
			TRACEACTION( "fpGetBufferInfo failed");

		GetLocalTime( &Time );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Stop the Frontend Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );
		TRACEACTION( PrintString );

		if(fpStop(Handle))
		{
			GetLocalTime( &Time );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend Stopped Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );
			TRACEACTION( PrintString );
		}
		else
		{	
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to stop the device, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		GetLocalTime( &Time );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Stop Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );
		TRACEACTION( PrintString );

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "SC 0x%x LastSaw 0x%x Diff 0x%x", Total / BytesPerSample, CurrentSaw, (Total / BytesPerSample) - CurrentSaw );
		TRACEACTION( PrintString );

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "SCTotal %d SCHits %d SCMin %d SCMax %d\n", SCTotal, SCHits, SCMin, SCMax );
		TRACEACTION( PrintString );

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Jumps %d JumpsSaw %d", Jumps, JumpsSaw );
		TRACEACTION( PrintString );

		Status = fpGetConnectionProperties( Handle, &SignalStrength, &NrOfCRCErrors, &NrOfSampleBlocks );
		if( Status == 0 )
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "fpGetConnectionProperties failed, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
		else
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, 
				"ConnectionProperties : SignalStrength %d NrOfCRCErrors %d NrOfSampleBlocks %d", 
				SignalStrength, NrOfCRCErrors, NrOfSampleBlocks);
			TRACEACTION( PrintString );
		}

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Got %d samples, loop %d\n", 
			TotalNrSamples, StartNr );
		TRACEACTION( PrintString );

		TRACEACTION( "End try loop");
		Sleep(10);
	}
#ifdef SAVE_SAMPLES
	fclose( ascf );
#endif

	fpFree( psf );
	free( SignalBuffer );
}

static void GetFileFromMobitaCard( void* Handle, unsigned int LoopNumber )
{
	int BytesPerSample;
	long BytesReturned;
	int i;
	int NrOfChannels = 0;
	PSIGNAL_FORMAT psf = NULL;
	SYSTEMTIME Time = {0};
	BOOLEAN Status;
	unsigned int *SignalBuffer, SizeOfSignalBufferInBytes ;
	int ErrorCode;
	unsigned int LastSaw=0;
	TMSiFileInfoType* FileList=NULL;
	int NrOfFiles;
	TMSiFileHeaderType APIFileHeader;
	unsigned int NoDataRecieved=0;
	unsigned int SignalStrength, NrOfCRCErrors, NrOfSampleBlocks;
	unsigned int TotalNrSamples=0;
	unsigned short OpenFileId ;

	FileList = fpGetCardFileList(Handle, &NrOfFiles );

	if( NrOfFiles == 0 )
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Zero files found, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		return;
	}

	if( FileList == NULL )
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Empty file list, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		return;
	}

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Found %d files on card", NrOfFiles );
	TRACEACTION( PrintString );

	for(i=0 ; i<NrOfFiles ; i++ )
	{
		const TMSiFileInfoType CurrFile = FileList[i] ;

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Fileid[%d] = %d : ", i, CurrFile.FileID );
		TRACEACTION( PrintString );

		DisplaySysTime( &(CurrFile.StartRecTime) );
		DisplaySysTime( &(CurrFile.StopRecTime) );
	}

	OpenFileId = FileList[NrOfFiles-1].FileID ;
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Opening file with fileid %d", OpenFileId );
	TRACEACTION( PrintString );

	Status = fpOpenCardFile( Handle, OpenFileId, &APIFileHeader );
	fpFree(FileList);
	FileList=NULL;

	if( Status == 0 )
	{
		ErrorCode = fpGetErrorCode( Handle );
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not open file on SD card, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		return;
	}

	TRACEACTION( "Timestamps from FileHeader:" );
	DisplaySysTime( &(APIFileHeader.StartRecTime));
	DisplaySysTime( &(APIFileHeader.EndRecTime));

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Number of samples in file = %d", APIFileHeader.NumberOfSamp );
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Call GetCardFileSignalFormat" );
	TRACEACTION( PrintString );
		
	psf = fpGetCardFileSignalFormat(Handle );
	if( psf != NULL ) 
	{	
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has %d channels", psf->Elements );
		TRACEACTION( PrintString );

		NrOfChannels = psf->Elements ;
		PrintChannelInformation( psf );

		fpFree( psf ); 
		psf = NULL;
	}	
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not get SignalFormat, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		return;
	}

	BytesPerSample = NrOfChannels * sizeof(long);
	// Determine the size in bytes and alloc
	SizeOfSignalBufferInBytes = sizeof(SignalBuffer[0]) * (APIFileHeader.RecordingSampleRate*2000) * NrOfChannels ;
	SignalBuffer = (unsigned int*) malloc(SizeOfSignalBufferInBytes);

	if( SignalBuffer == NULL )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not allocate %d bytes of memory for SignalBuffer", 
			SizeOfSignalBufferInBytes );
		TRACEACTION( PrintString );
		AppExit(1); 
	}

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "RecordingSampleRate in file = %d", APIFileHeader.RecordingSampleRate );
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Number of samples in file = %d", APIFileHeader.NumberOfSamp );
	TRACEACTION( PrintString );

	GetLocalTime( &Time );
	printf( "Start Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );

	if( fpStartCardFile( Handle) )
	{	
		const int ShowChannel = NrOfChannels - 1 ;
		int Sampling = 1 ;

		TRACEACTION( "Reading from card started, printing last channel");
		while(Sampling)
		{			
			// if there is data available get samples from the device
			// GetSamples returns the number of bytes written in the signal buffer
			// This will always be a multiple op BytesPerSample. 
			// Divide the result by BytesPerSamples to get the number of samples returned

			BytesReturned = fpGetCardFileSamples(Handle, (PULONG) SignalBuffer, SizeOfSignalBufferInBytes );
			if( BytesReturned > 0) 
			{	
				const int NrSamples = BytesReturned/BytesPerSample;

				GetLocalTime( &Time );

				TotalNrSamples+=NrSamples;
				NoDataRecieved=0;

				PrintSaw( TotalNrSamples, ShowChannel, SignalBuffer, NrSamples );

				for(i=0 ; i< NrSamples ; i++ )
				{
					int ActualSawDifference;
					const int SawIndex = (i+1)*NrOfChannels -1 ;
					const unsigned int RawValue =(unsigned int) SignalBuffer[SawIndex];

					unsigned int CurrentSaw = RawValue ;
					ActualSawDifference = (unsigned int) (( CurrentSaw - LastSaw ) & 0x7fff );

					if( ActualSawDifference != 0x1 )
					{
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "%d SC %d DIFF [%d]=%d (%d)", BytesReturned, TotalNrSamples, SawIndex, CurrentSaw, LastSaw );
						TRACEACTION( PrintString );
					}

					LastSaw = CurrentSaw ;
				}

				// Stop when you have all samples
				if( (LastSaw >= APIFileHeader.NumberOfSamp) || 
					(TotalNrSamples >= APIFileHeader.NumberOfSamp ))
				{
					sprintf_s( PrintString, LENGTH_PRINTSTRING, "Got %d samples from %d in file where LastSaw = %d", TotalNrSamples, APIFileHeader.NumberOfSamp, LastSaw );
					TRACEACTION( PrintString );
					Sampling = 0 ;
				}

				//sprintf_s( PrintString, LENGTH_PRINTSTRING, "%8d [%3d]=%3d #%d", Total / BytesPerSample , ShowChannel,SignalBuffer[ShowChannel], NrSamples );
				//TRACEACTION( PrintString );
			}
			else 
			{
				if( BytesReturned == 0 )
				{
					ULONG Overflow, PercentFull ;

					Status = fpGetBufferInfo( Handle, &Overflow, &PercentFull );

					if( Status && Overflow > 0 && PercentFull > 0 )
					{
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Overflow %d PercentFull %d", Overflow, PercentFull );
						TRACEACTION( PrintString );
					}

					//allow other applications some extra process time 
					Sleep(1);
				}
				else
				{
					// Negative value returned, so there is a problem.
					// Stop sampling now, jump out of the while loop
					Sampling = 0 ;

					sprintf_s( PrintString, LENGTH_PRINTSTRING,"Last Sample Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );
					TRACEACTION( PrintString );
					GetLocalTime( &Time );
					sprintf_s( PrintString, LENGTH_PRINTSTRING, "Negative Return at Min %d Sec %d mSec %d\n", Time.wMinute, Time.wSecond, Time.wMilliseconds );					TRACEACTION( PrintString );
					TRACEACTION( PrintString );	
					sprintf_s( PrintString, LENGTH_PRINTSTRING, "Negative return from fpGetCardFileSamples after %d samples, errorcode = %d (%s)", 
						TotalNrSamples, BytesReturned, fpGetErrorCodeMessage(Handle,BytesReturned) );
					TRACEACTION( PrintString );
				}
			}
		}
	}
	else 
	{	
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to start the Device, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	TRACEACTION("Get Connection Properties");
	Status = fpGetConnectionProperties( Handle, &SignalStrength, &NrOfCRCErrors, &NrOfSampleBlocks );
	if( Status == 0 )
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "fpGetConnectionProperties failed, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		AppExit(1);
	}
	else
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, 
			"fpGetConnectionProperties SignalStrength %d NrOfCRCErrors %d NrOfSampleBlocks %d", 
			SignalStrength, NrOfCRCErrors, NrOfSampleBlocks);
		TRACEACTION( PrintString );
	}

	TRACEACTION("\nStop reading the file from the card");
	if(fpStopCardFile(Handle))
	{
		TRACEACTION("Stopped reading the file from card");
	}
	else
	{	
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to stop reading the file from the card, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	TRACEACTION("\nClose the file from the card");
	if(fpCloseCardFile(Handle))
	{
		TRACEACTION("File from card closed");
	}
	else
	{	
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to close the file from card, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	free( SignalBuffer);
}

static void GetImpedanceData( void* Handle )
{
	ULONG SampleRateInMilliHz, SampleRateInHz ;
	ULONG SignalBufferSizeInSamples;
	int BytesReturned;
	int i;
	unsigned int *SignalBuffer, SignalBufferSizeInBytes ;
	int ErrorCode;
	PSIGNAL_FORMAT psf = NULL;
	int NumberOfChannels = 0 ;
	char FrontEndName[MAX_FRONTENDNAME_LENGTH];
	long BytesPerSample;
	int NoDataRecieved=0, Total=0;
	int Ohm;

	TRACEACTION( "Try to get the SignalFormat");
	psf = fpGetSignalFormat( Handle, FrontEndName ); 

	if( psf != NULL ) 
	{	
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "FrontEndName = [%s]", FrontEndName );
		TRACEACTION( PrintString );

		NumberOfChannels = psf->Elements ;
		PrintChannelInformation( psf );

		fpFree( psf ); 
		psf = NULL;
	}	
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not get SignalFormat, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		return;
	}

	BytesPerSample = NumberOfChannels * sizeof(long);

	if( BytesPerSample == 0 ) 
	{	
		TRACEACTION( "BytesPerSample == 0" );
		AppExit(1); 
	}

	// Set the samplerate in Herz
	SampleRateInMilliHz = 0 ;
	SignalBufferSizeInSamples = 1000 ;

	TRACEACTION( "Set the selected samplerate");
	if( fpSetSignalBuffer( Handle, &SampleRateInMilliHz,&SignalBufferSizeInSamples) != TRUE )
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "SetSignalBuffer 2 failed, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
		AppExit(1);
	}

	SampleRateInHz = SampleRateInMilliHz / 1000 ;

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Selected sample rate = %d Hz",SampleRateInMilliHz  / 1000 );
	TRACEACTION( PrintString );

	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Selected Buffer size = %d Samples", SignalBufferSizeInSamples);
	TRACEACTION( PrintString );

	// We know now the NumberOfChannels and the choosen SampleRateInHz, so allocate now the Signalbuffer
	SignalBufferSizeInBytes = SignalBufferSizeInSamples * NumberOfChannels * sizeof(SignalBuffer[0]);
	SignalBuffer = (unsigned int*) malloc( SignalBufferSizeInBytes );

	if( SignalBuffer == NULL )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not allocate %d bytes of memory for SignalBuffer", 
			SignalBufferSizeInBytes );
		TRACEACTION( PrintString );
		return;
	}

	// This loop demonstrate that you can set several different Ohm values
	// If you want just one specific value, remove the loop and use that specific value
	for( Ohm = IC_OHM_002 ; Ohm < IC_OHM_200 ; Ohm++ )
	{
		NoDataRecieved=Total=0;
		if( fpStart( Handle) )
		{
			TRACEACTION("Device started");
		}
		else
		{	
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to stop the device, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
			return;
		}

		// Turn on the impendance mode
		if( fpSetMeasuringMode( Handle, MEASURE_MODE_IMPEDANCE_EX, Ohm ))
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Measuremode impedance set to %d", Ohm );
			TRACEACTION( PrintString );
		}
		else
		{	
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to set Measuremode impedance, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
			free(SignalBuffer);
			return;
		}

		// Get impedance data
		for( i=0 ; i<1000 ; i++ )
		{			
			BytesReturned = fpGetSamples(Handle, (PULONG) SignalBuffer, SignalBufferSizeInBytes );
			if( BytesReturned > 0) 
			{	
				const int NrSamples = BytesReturned/(NumberOfChannels*sizeof(unsigned int));

				Total += BytesReturned; 
				printf("\rSC %8d IMP %3d %3d %3d %3d #%d ", Total / BytesPerSample , SignalBuffer[0], SignalBuffer[1], SignalBuffer[2], SignalBuffer[3], NrSamples );
			}
			else 
			{
				if( BytesReturned == 0 )
				{
					//allow other applications some extra process time 
					Sleep(1);
					NoDataRecieved++ ;
					//printf( "Sleep %d\n", NoDataRecieved );

					if( NoDataRecieved > 1000 )
					{
						// Several time no data recieved
						// Stop sampling now, jump out of the while loop
						printf( "No data %d\n", NoDataRecieved );
						break;
					}
				}
				else
				{
					// Negative value returned, so there is a problem.
					// Stop sampling now, jump out of the while loop
					printf( "Negative value %d after %d reads\n", BytesReturned, NoDataRecieved );
					break;
				}
			}
		}

		// Turn off the impendance mode, and go back to normal (=sampling) mode
		if( fpSetMeasuringMode( Handle, MEASURE_MODE_NORMAL, 0 ))
		{
			TRACEACTION("Measuremode normal set");
		}
		else
		{	
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to set Measuremode normal, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
			free(SignalBuffer);
			return;
		}

		if(fpStop(Handle))
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend Stopped\n" );
			TRACEACTION( PrintString );
		}
		else
		{	
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Unable to stop the device, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
	}

	free(SignalBuffer);
	SignalBuffer=NULL;
}

static void NeXus10MkIIFunc(void* Handle )
{
	BOOLEAN Status;
	int ErrorCode;
	char *RandomKey;
	unsigned int LengthKeyInBytes;
	unsigned short *RetrievedOEMData;
	unsigned int RetrievedOEMDataLengthInBytes;
	unsigned short *CreatedOEMData;
	unsigned int i,j;

	LengthKeyInBytes = 130 ;
	RandomKey = (char*) malloc(LengthKeyInBytes);

	Status = fpGetRandomKey( Handle, RandomKey, &LengthKeyInBytes );
	if( Status )
	{
		TRACEACTION( "GetRandomKey succes");
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetRandomKey, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	// Now you have a random key from the frontend
	// Transform this key using your company specific algorithm
	for(i=0 ; i<LengthKeyInBytes ; i++ )
		RandomKey[i] = 1 * RandomKey[i] ;

	// Send the transformed key to the device to unlock the device
	Status = fpUnlockFrontEnd( Handle, RandomKey, &LengthKeyInBytes );
	if( Status )
	{
		TRACEACTION( "UnlockFrontEnd succes");
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not UnlockFrontEnd, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	Status = fpGetOEMSize( Handle, &RetrievedOEMDataLengthInBytes );
	if( Status )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Retrieved OEMSize = %d bytes", 
			RetrievedOEMDataLengthInBytes	);
		TRACEACTION( PrintString );
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetOEMSize, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	if( Status && RetrievedOEMDataLengthInBytes > 0 )
	{
		unsigned int CreatedOEMDataLengthInBytes = RetrievedOEMDataLengthInBytes ;

		CreatedOEMData = (unsigned short*) malloc(CreatedOEMDataLengthInBytes);

		// Fill the start and end point of the buffer with visual markers
		for(i=0 ; i<CreatedOEMDataLengthInBytes/0x100 ; i++ )
		{	
			const unsigned int PayLoadLength = 0x80 ; 
			const unsigned int IndexBegin = i*PayLoadLength ;
			const unsigned int IndexEnd = (i+1)*PayLoadLength-1;

			for(j=0 ; j<PayLoadLength ; j++ )
				CreatedOEMData[IndexBegin+j] = (short) ('a' + i );

			CreatedOEMData[IndexBegin] = '[' ;
			CreatedOEMData[IndexEnd] = ']' ;
		}

		Status = fpSetOEMData(Handle, (const char*) CreatedOEMData, CreatedOEMDataLengthInBytes );
		if( Status )
		{
			TRACEACTION( "SetOEMData success" );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not SetOEMData, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		RetrievedOEMData = (unsigned short*) malloc(RetrievedOEMDataLengthInBytes);
		memset(	RetrievedOEMData, 0, RetrievedOEMDataLengthInBytes);

		printf( "Wait for flashmemory to finish\n");
		Sleep(1000);

		printf( "Now get data from flashmemory\n");
		Status = fpGetOEMData(Handle, (char*) RetrievedOEMData, &RetrievedOEMDataLengthInBytes );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Retrieved BinaryOEMData = %d bytes", 
				RetrievedOEMDataLengthInBytes	);
			TRACEACTION( PrintString );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetOEMData, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		// Check if you got the same amount of data as you put in the frontend
		if( RetrievedOEMDataLengthInBytes != CreatedOEMDataLengthInBytes )
		{
			TRACEACTION( "Difference between length of CreatedOEMData and RetrievedOEMData" );
		}

		// Check if you got the same data as you put in the frontend
		if( strncmp( (const char*) CreatedOEMData,  (const char*) RetrievedOEMData, RetrievedOEMDataLengthInBytes ) == 0 )
		{
			TRACEACTION( "CreatedOEMData and RetrievedOEMDatais the same" );
		}
		else
		{
			TRACEACTION( "Difference between CreatedOEMData and RetrievedOEMData" );
		}

		free( RetrievedOEMData );
		free( CreatedOEMData );
	}

	free( RandomKey );
}

static void NeXus10MkIISensor(void* Handle )
{
	BOOLEAN Status;
	int ErrorCode;
	char *RandomKey;
	unsigned int LengthKeyInBytes;
	unsigned short *RetrievedSensorData;
	unsigned int RetrievedSensorDataLengthInBytes = 256 ;
	unsigned short *GivenSensorData;
	unsigned int i,j;

	LengthKeyInBytes = 130 ;
	RandomKey = (char*) malloc(LengthKeyInBytes);

	Status = fpGetRandomKey( Handle, RandomKey, &LengthKeyInBytes );
	if( Status )
	{
		TRACEACTION( "GetRandomKey succes");
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetRandomKey, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	// Now you have a random key from the frontend
	// Transform this key using your company specific algorithm
	for(i=0 ; i<LengthKeyInBytes ; i++ )
		RandomKey[i] = 1 * RandomKey[i] ;

	// Send the transformed key to the device to unlock the device
	Status = fpUnlockFrontEnd( Handle, RandomKey, &LengthKeyInBytes );
	if( Status )
	{
		TRACEACTION( "UnlockFrontEnd succes");
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not UnlockFrontEnd, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	if( Status && RetrievedSensorDataLengthInBytes > 0 )
	{
		unsigned int GivenDataSizeInBytes = RetrievedSensorDataLengthInBytes ;
		const unsigned int PayLoadLength = GivenDataSizeInBytes/2 ; 
		const unsigned int IndexBegin = 0 ;
		const unsigned int IndexEnd = PayLoadLength-1;

		GivenSensorData = (unsigned short*) malloc(GivenDataSizeInBytes);

		for(j=0 ; j<PayLoadLength ; j++ )
			GivenSensorData[IndexBegin+j] = (short) ('z');

		GivenSensorData[IndexBegin] = '[' ;
		GivenSensorData[IndexEnd] = ']' ;

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Calling SetSensorData with %d bytes", GivenDataSizeInBytes );
		TRACEACTION( PrintString );
		Status = fpSetDigSensorData(Handle, GivenDataSizeInBytes, (unsigned char*) GivenSensorData );
		if( Status )
		{
			TRACEACTION( "SetSensorData success" );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not SetSensorData, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
		
		RetrievedSensorData = (unsigned short*) malloc(RetrievedSensorDataLengthInBytes);
		memset(	RetrievedSensorData, 0, RetrievedSensorDataLengthInBytes);
	
		printf( "Wait for flashmemory to finish\n");
		Sleep(1000);

		printf( "Now get data from flashmemory\n");
		Status = fpGetDigSensorData(Handle, &RetrievedSensorDataLengthInBytes, (unsigned char*) RetrievedSensorData );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Retrieved BinarySensorData = %d bytes", 
				RetrievedSensorDataLengthInBytes	);
			TRACEACTION( PrintString );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetSensorData, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		// Check if you got the same amount of data as you put in the frontend
		if( RetrievedSensorDataLengthInBytes != GivenDataSizeInBytes )
		{
			TRACEACTION( "Difference between length of GivenSensorData and RetrievedSensorData" );
		}

		// Check if you got the same data as you put in the frontend
		if( memcmp( (const char*) GivenSensorData,  (const char*) RetrievedSensorData, RetrievedSensorDataLengthInBytes ) == 0 )
		{
			TRACEACTION( "GivenSensorData and RetrievedSensorDatais the same" );
		}
		else
		{
			TRACEACTION( "Difference between GivenSensorData and RetrievedSensorData" );
		}

		free( RetrievedSensorData );
		free( GivenSensorData );
	}

	free( RandomKey );
}




static void NeXus4Func(void* Handle )
{
	BOOLEAN Status;
	int ErrorCode;
	long FlashStatus ;
	ULONG SignalBufferSizeInBytes; 
	int RetrievedBytes, TotalRetrievedBytes;
	PULONG SignalBuffer;
	int StartAdress=0;
	int FlashBlockLengthInWords = 0x80 ;
	int i ;

	Status = fpGetFlashStatus( Handle, &FlashStatus );
	if( Status )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "FlashStatus = %x", FlashStatus);
		TRACEACTION( PrintString );
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetFlashStatus, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	SignalBufferSizeInBytes = FlashBlockLengthInWords * sizeof(short);
	SignalBuffer = (PULONG) malloc( SignalBufferSizeInBytes );

	for(i=0;i<FlashBlockLengthInWords/2; i++ )
		SignalBuffer[i] = i ;

	Status = fpSetFlashData(Handle, 0, SignalBuffer, FlashBlockLengthInWords );
	if( Status )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "SetFlashData = %x", Status);
		TRACEACTION( PrintString );
	}
	else
	{
		ErrorCode = fpGetErrorCode(Handle);
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not SetFlashData, errorcode = %d (%s)", 
			ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
		TRACEACTION( PrintString );
	}

	do {
		// Get the status after flash
		Sleep(1000);
		Status = fpGetFlashStatus( Handle, &FlashStatus );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "FlashStatus = %x", FlashStatus);
			TRACEACTION( PrintString );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetFlashStatus, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
	}
	while( ( FlashStatus & 0x4 ) == 0x4 );

	TRACEACTION( "Ready after write");

	free(SignalBuffer);
	FlashBlockLengthInWords = 0x8000 ;
	SignalBufferSizeInBytes = FlashBlockLengthInWords * sizeof(short);
	SignalBuffer = (PULONG) malloc( SignalBufferSizeInBytes );

	while( StartAdress < 400*FlashBlockLengthInWords)
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "StartFlashData calling..." );
		TRACEACTION( PrintString );

		Status = fpStartFlashData( Handle, StartAdress, FlashBlockLengthInWords );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "StartFlashData called" );
			TRACEACTION( PrintString );
			TotalRetrievedBytes = 0 ;

			do
			{
				memset( SignalBuffer, 0xbad0, SignalBufferSizeInBytes );
				RetrievedBytes = fpGetFlashSamples( Handle, SignalBuffer, SignalBufferSizeInBytes );
				if( RetrievedBytes < 0 )
				{
					ErrorCode = fpGetErrorCode(Handle);
					sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not FlashSamples, errorcode = %d (%s)", 
						ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
					TRACEACTION( PrintString );
				}
				else
				{
					if( RetrievedBytes > 0 )
					{
						TotalRetrievedBytes += RetrievedBytes;

						sprintf_s( PrintString, LENGTH_PRINTSTRING, "TotalRetrievedBytes = %d", TotalRetrievedBytes );
						TRACEACTION( PrintString );
					}
					else
					{
						ULONG Overflow, PercentFull ;

						Status = fpGetBufferInfo( Handle, &Overflow, &PercentFull );

						if( Status != 0 && Overflow > 0 && PercentFull > 0 )
						{
							sprintf_s( PrintString, LENGTH_PRINTSTRING, "Overflow %d PercentFull %d", Overflow, PercentFull );
							TRACEACTION( PrintString );
						}

						//allow other applications some extra process time 
						Sleep(1);
					}
				}
			}	
			while( RetrievedBytes >= 0 && TotalRetrievedBytes < (FlashBlockLengthInWords*2) );

			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Total Retrieved FlashSamples = %d bytes for Adress %d", TotalRetrievedBytes, StartAdress );
			TRACEACTION( PrintString );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not StartFlashData, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "StopFlashData calling..." );
		TRACEACTION( PrintString );

		Status = fpStopFlashData( Handle );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "StopFlashData called" );
			TRACEACTION( PrintString );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not StopFlashData, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		StartAdress += FlashBlockLengthInWords*sizeof(short) ;
	}

	// Warning: This tested and fully functionall code will ERASE ALL recordings on the flash memory of the Nexus4
	/*
	Status = fpFlashEraseMemory( Handle );
	if( Status )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "FlashEraseMemory called" );
		TRACEACTION( PrintString );
	}
	else
	{
	ErrorCode = fpGetErrorCode(Handle);
	sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not FlashEraseMemory, errorcode = %d (%s)", 
	ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
	TRACEACTION( PrintString );
	}
	*/

	do {
		// Get the status after flash
		Sleep(1000);
		Status = fpGetFlashStatus( Handle, &FlashStatus );
		if( Status )
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "FlashStatus = %x", FlashStatus);
			TRACEACTION( PrintString );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not GetFlashStatus, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
	}
	while( ( FlashStatus & 0x4 ) == 0x4 );

	free(SignalBuffer);
}

int main(int argc, char* argv[])
{	
	HANDLE Handle = NULL;			//Device Handle
	HINSTANCE LibHandle;	//Liberary Handle
	int i;
	BOOLEAN Status;
	char **DeviceList = NULL;
	int NrOfDevices=0;
	TCHAR Path[	MAX_PATH ]; 
	int ErrorCode=0;
	TMSiBatReportType TMSiBatReport;
	TMSiStorageReportType TMSiStorageReport;
	TMSiDeviceReportType TMSiDeviceReport;
	TMSiExtFrontendInfoType TMSiExtFrontEndInfo ;
	FRONTENDINFO FrontEndInfo ;
	TCHAR LibraryName[255] = _T("\\TMSiSDK.dll"); 
	int OpenCloseLoop;
	SYSTEMTIME Time; 

	TRACEACTION( "ExampleCode.exe $Revision: 143 $" );

	switch(sizeof(size_t))
	{
	case 4:
		TRACEACTION("32bits exe");
		break;
	case 8:
		TRACEACTION("64bits exe");
		break;	
	default: 
		TRACEACTION("00bits exe");
		break;
	}

	if( argc  < 2  )
	{
		TRACEACTION("Usage: example (w=WLAN, u=USB b=Bluetooth n=Network) s=sample [loops][sawtoothdiff][sawtoothmask][loopminutes][samplerate], i=impedance, f=file t=timed recording [s = set, g = get] [minute offset]");
		AppExit(1);
	}	

	// On Windows XP SP 3, the expected sytem path is "\WINDOWS\system32"
	TRACEACTION( "Create system path for library");
	GetSystemDirectory(Path, sizeof(Path) / sizeof(TCHAR) );
	lstrcat(Path, LibraryName);

#ifdef TMSI_DEBUG
	{
		TCHAR Hardcoded[255] = _T("..\\TmsiApi\\Debug\\TMSiSDK.dll"); 
		Path[0] = 0 ; // When debugging, use the locally build lib
		lstrcat(Path, Hardcoded);
	}
#endif

	TRACEACTION( "Try to load the library in");
	for(i=0 ; i<MAX_PATH; i++ )
		PrintString[i] = (char) Path[i];
	TRACEACTION( PrintString);
	LibHandle = LoadLibrary(Path); 

	if( LibHandle == NULL ) 
	{
		// If you can not load the library, there are some things which could be wrong:
		// 1) The path you specified is wrong
		// 2) The TMSiSDK.dll was not installed on this pc
		// 3) The PC does not have the Visual Studio 2010 C++ redistributable library installed
		// 4) LibHandle == NULL and Error 126 (The specified module could not be found.) means that the module 
		// is  not found in the directory which was given
		// When loading the library from a managed program (C#/C++), the OS can report:
		// "The specified module could not be found. (Exception from HRESULT: 0x8007007E)"
		// This has the same reason as 3) above. See
		// http://blogs.msdn.com/b/junfeng/archive/2006/07/31/684596.aspx
		// On 64bit: Error code 193 : ERROR_BAD_EXE_FORMAT (0xC1) %1 is not a valid Win32 application.

		const DWORD WinError = GetLastError();

		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not load library, windows errorcode = %d", WinError );
		TRACEACTION( PrintString );
		AppExit(1);
	}

	TRACEACTION( "Get pointers to the functions in the DLL");
	fpOpen				= (POPEN)			GetProcAddress(LibHandle,"Open");
	fpClose				= (PCLOSE)			GetProcAddress(LibHandle,"Close");
	fpStart				= (PSTART)			GetProcAddress(LibHandle,"Start");
	fpStop				= (PSTOP)			GetProcAddress(LibHandle,"Stop");
	fpSetSignalBuffer	= (PSETSIGNALBUFFER)GetProcAddress(LibHandle,"SetSignalBuffer");
	fpGetSamples		= (PGETSAMPLES)		GetProcAddress(LibHandle,"GetSamples");
	fpGetBufferInfo		= (PGETBUFFERINFO)	GetProcAddress(LibHandle,"GetBufferInfo");
	fpGetSignalFormat	= (PGETSIGNALFORMAT)GetProcAddress(LibHandle,"GetSignalFormat"); 
	fpFree				= (PFREE)			GetProcAddress(LibHandle, "Free" ); 
	fpLibraryInit		= (PLIBRARYINIT)	GetProcAddress(LibHandle, "LibraryInit" ); 
	fpLibraryExit		= (PLIBRARYEXIT)	GetProcAddress(LibHandle, "LibraryExit" ); 
	fpGetFrontEndInfo	= (PGETFRONTENDINFO) GetProcAddress(LibHandle, "GetFrontEndInfo" ); 
	fpSetRtcTime		= (PSETRTCTIME)		GetProcAddress(LibHandle, "SetRtcTime" ); 
	fpGetRtcTime		= (PGETRTCTIME)		GetProcAddress(LibHandle, "GetRtcTime" ); 
	fpSetRtcAlarmTime	= (PSETRTCALARMTIME)GetProcAddress(LibHandle, "SetRtcAlarmTime" ); 
	fpGetRtcAlarmTime	= (PGETRTCALARMTIME)GetProcAddress(LibHandle, "GetRtcAlarmTime" ); 
	fpGetErrorCode		= (PGETERRORCODE)	GetProcAddress(LibHandle, "GetErrorCode" ); 
	fpGetErrorCodeMessage = (PGETERRORCODEMESSAGE) GetProcAddress(LibHandle, "GetErrorCodeMessage" ); 
	fpGetDeviceList		= (PGETDEVICELIST)	GetProcAddress(LibHandle, "GetDeviceList" ); 
	fpFreeDeviceList	= (PFREEDEVICELIST)	GetProcAddress(LibHandle, "FreeDeviceList" ); 
	fpStartCardFile		= (PSTARTCARDFILE)	GetProcAddress(LibHandle, "StartCardFile" ); 
	fpStopCardFile		= (PSTOPCARDFILE)	GetProcAddress(LibHandle, "StopCardFile" ); 
	fpGetCardFileSamples	= (PGETCARDFILESAMPLES)	GetProcAddress(LibHandle, "GetCardFileSamples" ); 
	fpGetConnectionProperties = (PGETCONNECTIONPROPERTIES)	GetProcAddress(LibHandle, "GetConnectionProperties" ); 
	fpGetCardFileSignalFormat = (PGETCARDFILESIGNALFORMAT) GetProcAddress(LibHandle, "GetCardFileSignalFormat" ); 
	fpOpenCardFile		= (POPENCARDFILE) GetProcAddress(LibHandle, "OpenCardFile" ); 
	fpGetCardFileList	= (PGETCARDFILELIST) GetProcAddress(LibHandle, "GetCardFileList" ); 
	fpCloseCardFile		= (PCLOSECARDFILE) GetProcAddress(LibHandle, "CloseCardFile" );
	fpGetExtFrontEndInfo = (PGETEXTFRONTENDINFO) GetProcAddress(LibHandle, "GetExtFrontEndInfo");
	fpSetMeasuringMode	= (PSETMEASURINGMODE) GetProcAddress(LibHandle, "SetMeasuringMode" );
	fpGetRecordingConfiguration = (PGETRECORDINGCONFIGURATION) GetProcAddress(LibHandle, "GetRecordingConfiguration" );
	fpSetRecordingConfiguration = (PSETRECORDINGCONFIGURATION) GetProcAddress(LibHandle, "SetRecordingConfiguration" );
	fpSetRefCalculation = (PSETREFCALCULATION) GetProcAddress(LibHandle, "SetRefCalculation" );
	fpGetRandomKey = (PGETRANDOMKEY) GetProcAddress(LibHandle, "GetRandomKey");
	fpUnlockFrontEnd=(PUNLOCKFRONTEND) GetProcAddress(LibHandle, "UnlockFrontEnd");
	fpGetOEMSize=(PGETOEMSIZE) GetProcAddress(LibHandle, "GetOEMSize");
	fpGetOEMData=(PGETOEMDATA) GetProcAddress(LibHandle, "GetOEMData");
	fpSetOEMData=(PSETOEMDATA) GetProcAddress(LibHandle, "SetOEMData");
	fpOpenFirstDevice = (POPENFIRSTDEVICE) GetProcAddress(LibHandle, "OpenFirstDevice" );
	fpSetStorageMode = (PSETSTORAGEMODE) GetProcAddress(LibHandle, "SetStorageMode");

	// Nexus4
	fpGetFlashStatus = (PGETFLASHSTATUS) GetProcAddress(LibHandle, "GetFlashStatus");
	fpStartFlashData = (PSTARTFLASHDATA) GetProcAddress(LibHandle, "StartFlashData");
	fpGetFlashSamples = (PGETFLASHSAMPLES) GetProcAddress(LibHandle, "GetFlashSamples");
	fpStopFlashData = (PSTOPFLASHDATA) GetProcAddress(LibHandle, "StopFlashData");
	fpFlashEraseMemory = (PFLASHERASEMEMORY) GetProcAddress(LibHandle, "FlashEraseMemory" );
	fpSetFlashData = (PSETFLASHDATA) GetProcAddress(LibHandle, "SetFlashData" );
	fpSetChannelReferenceSwitch = (PSETCHANNELREFERENCESWITCH) GetProcAddress(LibHandle, "SetChannelReferenceSwitch");
	
	// Nextus
	fpGetDigSensorData = (PGETDIGSENSORDATA) GetProcAddress(LibHandle, "GetDigSensorData");
	fpSetDigSensorData = (PSETDIGSENSORDATA) GetProcAddress(LibHandle, "SetDigSensorData");

	// Check if the function pointer is loaded
	if( fpLibraryInit == NULL ) 
	{
		TRACEACTION( "functions in library not found");
		AppExit(1);
	}

	TRACEACTION( "Call LibraryInit");

	if( *argv[1] == 'w' )
	{
		TRACEACTION( "Use WLAN");
		Handle = fpLibraryInit( TMSiConnectionWifi, &ErrorCode );
	}

	if( *argv[1] == 'u' )
	{
		TRACEACTION( "Use USB");
		Handle = fpLibraryInit( TMSiConnectionUSB, &ErrorCode );
	}

	if( *argv[1] == 'b' )
	{
		TRACEACTION( "Use Bluetooth");
		Handle = fpLibraryInit( TMSiConnectionBluetooth, &ErrorCode );
	}

	if( *argv[1] == 'n' )
	{
		TRACEACTION( "Use network");
		Handle = fpLibraryInit( TMSiConnectionNetwork, &ErrorCode );
	}

	if( ErrorCode != 0 )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not initialize library, errorcode = %d", ErrorCode );
		TRACEACTION( PrintString );
		AppExit(1);
	}

	if( Handle == INVALID_HANDLE_VALUE )
	{
		sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not initialize library, INVALID_HANDLE_VALUE" );
		TRACEACTION( PrintString );
		AppExit(1);
	}

	// This loop demonstrates which call to do if you want to repeatedly open and close a frontend
	// If you want to see how to start and stop sampling, see GetSampleDataWhileMeasuring()
	for(OpenCloseLoop=0 ;OpenCloseLoop < 1 ; OpenCloseLoop++ )
	{
		TRACEACTION( "Try to list all frontends");
		DeviceList = fpGetDeviceList( Handle, &NrOfDevices);
		if( NrOfDevices == 0 )
		{
			ErrorCode = fpGetErrorCode( Handle );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend list NOT available, errorcode = %d (%s)", ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
			fpLibraryExit( Handle );
			AppExit(1);
		}
		else
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Found %d connections", NrOfDevices );
			TRACEACTION( PrintString );

			for(i=0 ; i< NrOfDevices ; i++ )
			{
				sprintf_s( PrintString, LENGTH_PRINTSTRING, "%d = [%s]", 
					i, DeviceList[i] );
				TRACEACTION( PrintString );
			}
		}

		Status = 0 ;
		if( DeviceList !=NULL && DeviceList[0] != NULL )
		{
			char *DeviceLocator = DeviceList[0] ;

			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Try to connect to the frontend using [%s] (%d chars)", 
				DeviceLocator, strlen(DeviceLocator) );
			TRACEACTION( PrintString );
			Status = fpOpen( Handle, DeviceLocator );
		}

		if( Status == 0 )
		{
			ErrorCode = fpGetErrorCode( Handle );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend NOT available, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
			fpLibraryExit( Handle );
			AppExit(1);
		}
		else
		{
			TRACEACTION( "Device connected" );
		}

		// To turn the reference calculation on, set the parameter to 1
		Status = fpSetRefCalculation( Handle, 1 );
		if( Status == 0 )
		{
			ErrorCode = fpGetErrorCode( Handle );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "SetRefCalculation NOT set, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
		else
		{
			TRACEACTION( "SetRefCalculation set" );
		}

		Status = fpGetFrontEndInfo( Handle, &FrontEndInfo );
		if( Status == 0 )
		{
			ErrorCode = fpGetErrorCode( Handle );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "FrontendInfo NOT available, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
		else
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has Serial %d", FrontEndInfo.Serial );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has HwVersion 0x%x", FrontEndInfo.HwVersion );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has SwVersion 0x%x", FrontEndInfo.SwVersion );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has BaseSf %d", FrontEndInfo.BaseSf );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has maxRS232 %d", FrontEndInfo.maxRS232 );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Frontend has %d channels", FrontEndInfo.NrOfChannels );
			TRACEACTION( PrintString );
		}

		// GetExtFrontEndInfo is only for Mobita
		Status = fpGetExtFrontEndInfo( Handle, &TMSiExtFrontEndInfo, &TMSiBatReport, &TMSiStorageReport, &TMSiDeviceReport );
		if( Status == 0 )
		{
			ErrorCode = fpGetErrorCode( Handle );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "GetExtFrontEndInfo NOT available, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
		else
		{
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "CurrentSamplerate %d Hz", TMSiExtFrontEndInfo.CurrentSamplerate );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "CurrentInterface %d", TMSiExtFrontEndInfo.CurrentInterface );
			TRACEACTION( PrintString );

			sprintf_s( PrintString, LENGTH_PRINTSTRING, "MemoryStatus.TotalSize %d MByte",  TMSiStorageReport.TotalSize );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "MemoryStatus.UsedSpace %d MByte",  TMSiStorageReport.UsedSpace );
			TRACEACTION( PrintString );

			sprintf_s( PrintString, LENGTH_PRINTSTRING, "BatteryStatus.AccumCurrent %d mAh", TMSiBatReport.AccumCurrent );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "BatteryStatus.Current %d mA", TMSiBatReport.Current );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "BatteryStatus.Temp %d C",  TMSiBatReport.Temp );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "BatteryStatus.Voltage %d mV",  TMSiBatReport.Voltage );
			TRACEACTION( PrintString );

			sprintf_s( PrintString, LENGTH_PRINTSTRING, "TMSiDeviceReport.AdapterSerial %d",  TMSiDeviceReport.AdapterSN );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "TMSiDeviceReport.AdapterStatus %d",  TMSiDeviceReport.AdapterStatus );
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "TMSiDeviceReport.MobitaSerial %d",  TMSiDeviceReport.MobitaSN);
			TRACEACTION( PrintString );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "TMSiDeviceReport.MobitaStatus %d",  TMSiDeviceReport.MobitaStatus);
			TRACEACTION( PrintString );
		}

		TRACEACTION( "Try to get the time");
		Status = fpGetRtcTime( Handle, &Time );
		if( Status == 1 )
		{
			TRACEACTION( "Time get");
			DisplaySysTime( &Time );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not get time, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}


		TRACEACTION( "Try to set the time");
		GetLocalTime( &Time );
		Status = fpSetRtcTime( Handle, &Time );
		if( Status == 1 )
		{
			TRACEACTION( "Time set");
			DisplaySysTime( &Time );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not set time, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		TRACEACTION( "Try to get the time again");
		Status = fpGetRtcTime( Handle, &Time );
		if( Status == 1 )
		{
			TRACEACTION( "Time get again");
			DisplaySysTime( &Time );
		}
		else
		{
			ErrorCode = fpGetErrorCode(Handle);
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not get time again, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}

		if( argc > 2 )
		{
			if( *argv[2] == 's' )
			{
				unsigned int ExpectedSawDifference = 1 ;
				unsigned int ExpectedSawMask = 0xffff ;
				unsigned int LoopNumber = 1 ;
				unsigned int DesiredSampleMinutes = 1 ;
				int DesiredSampleRate = -1 ;

				if( argc>3 )
					LoopNumber = atoi(argv[3]);

				if( argc>4 )
					ExpectedSawDifference = strtol(argv[4], NULL, 16 );

				if( argc>5 )
					ExpectedSawMask = strtol(argv[5], NULL, 16 );

				if( argc>6 )
					DesiredSampleMinutes = atoi(argv[6]);

				if( argc>7 )
					DesiredSampleRate = atoi(argv[7]);

				// EPU = u s 1 1 ffffffff
				sprintf_s( PrintString, LENGTH_PRINTSTRING, 
					"Use sampling with %d loops and sawtoothdiff %d sawtoothmask %d for %d minutes",  
					LoopNumber, ExpectedSawDifference, ExpectedSawMask, DesiredSampleMinutes, DesiredSampleRate );
				TRACEACTION( PrintString );

				GetSampleDataWhileMeasuring( Handle, LoopNumber, ExpectedSawDifference, ExpectedSawMask, 
					DesiredSampleMinutes, DesiredSampleRate );
			}

			if( *argv[2] == 'i' )
			{
				sprintf_s( PrintString, LENGTH_PRINTSTRING, "Use impedance measurement" );
				TRACEACTION( PrintString );

				GetImpedanceData( Handle );
			}

			if( *argv[2] == 'f' )
			{
				unsigned int LoopNumber = 1 ;

				if( argc>3 )
					LoopNumber = atoi(argv[3]);

				TRACEACTION("Get file from mobita card");
				GetFileFromMobitaCard( Handle, LoopNumber );
			}

			if( *argv[2] == 'r' )
			{
				unsigned long ChannelMask = 0 ;

				if( argc>3 )
					ChannelMask = strtol(argv[3], NULL, 16 );

				// EPU = u r abcdeffff
				sprintf_s( PrintString, LENGTH_PRINTSTRING, "Set ChannelReferenceSwitch with 0x%x",  ChannelMask );
				TRACEACTION( PrintString );

				Status = fpSetChannelReferenceSwitch( Handle, sizeof(ChannelMask), (unsigned char*) &ChannelMask );

				if( Status == 0 )
				{
					ErrorCode = fpGetErrorCode( Handle );
					sprintf_s( PrintString, LENGTH_PRINTSTRING, "Can not set ChannelReferenceSwitch, errorcode = %d (%s)", 
						ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
					TRACEACTION( PrintString );
				}
			}

			if( *argv[2] == '4' )
			{
				TRACEACTION("Get memoryfile from nexus4 card");
				NeXus4Func( Handle );
			}

			if( *argv[2] == 'm' )
			{
				sprintf_s( PrintString, LENGTH_PRINTSTRING, "Use Nexus10MKII" );
				TRACEACTION( PrintString );

				NeXus10MkIISensor( Handle );
				//NeXus10MkIIFunc( Handle );
			}

			if( *argv[2] == 't' )
			{
				WORD MinutesOfOffset = 1 ;
				WORD TimeToMeasure = 1 ;

				if( argc>4 )
					MinutesOfOffset = (WORD) atoi(argv[4]);

				if( argc>5 )
					TimeToMeasure = (WORD) atoi(argv[5]);

				if( argc>3 )
				{
					if( *argv[3] == 's' )
					{
						// u t s 0 for setting manual start
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Set timed recording with %d minute offset",  MinutesOfOffset );
						TRACEACTION( PrintString );

						SetRecordingSchedule( Handle, MinutesOfOffset, TimeToMeasure );
					}

					if( *argv[3] == 'g' )
					{
						// u t g for getting already defined configuration
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Get timed recording with %d minute offset",  MinutesOfOffset );
						TRACEACTION( PrintString );

						GetRecordingSchedule( Handle );
					}

					if( *argv[3] == 'w' )
					{
						// u t w for only turning on wifi
						sprintf_s( PrintString, LENGTH_PRINTSTRING, "Turn Wifi on");
						TRACEACTION( PrintString );

						SetWifiOn( Handle );
					}
				}
				else
				{
					TRACEACTION( "Error : choose s for set timed recording or g for get timed recording");
				}
			}
		}

		TRACEACTION("Call Close");
		Status = fpClose( Handle );
		if( Status == 0 )
		{
			ErrorCode = fpGetErrorCode( Handle );
			sprintf_s( PrintString, LENGTH_PRINTSTRING, "Close, errorcode = %d (%s)", 
				ErrorCode, fpGetErrorCodeMessage(Handle,ErrorCode) );
			TRACEACTION( PrintString );
		}
		else
		{
			TRACEACTION("Device closed");
		}

		// Wait for 1 second
		Sleep(1000);
	}

	TRACEACTION( "Free the DeviceList");
	if( DeviceList != NULL )
		fpFreeDeviceList( Handle, NrOfDevices, DeviceList );	

	TRACEACTION("Call LibraryExit");
	fpLibraryExit( Handle );

	FreeLibrary(LibHandle); 

	TRACEACTION("Close the log file");
	fclose (fp );

	return 0;
}
