classdef oxfordRateTestData < rateTestDataImporter
    % Concrete rate test data interface for facility correlation analysis
    % for Oxford data    
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Maccor"              % Type of battery tester
        Facility              correlationFacility   = "Oxford"              % Facility name
    end % abstract & constant properties
       
    properties ( SetAccess = protected )
        Current               string                = "Amps"                % Name of current channel
        Capacity              string                = "Amp-hr"              % Name of capacity channel
    end % protected properties
    
    methods
        function obj = oxfordRateTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % oxfordRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = oxfordRateTestData( BatteryId, RootDir );
            %
            % Input Arguments:
            %
            % BatteryId         --> (string) Name of battery {"LGM50"}
            % RootDir           --> Root directory where data is held. User 
            %                       is prompted for the directory if empty
            %--------------------------------------------------------------
            if ( nargin < 1 ) || isempty( BatteryId )
                obj.Battery = "LGM50";                                      % Apply default
            else
                obj = obj.setBattery( BatteryId );
            end
            if ( nargin < 2 ) || isempty( RootDir )
                RootDir = uigetdir( cd, "Select root directory containing Lancaster rate test data" );
            elseif ~isfolder( RootDir )
                error( '"%s" is not a valid folder', RootDir );
            end
            RootDir = string( RootDir );
            %--------------------------------------------------------------
            % Create data store
            %--------------------------------------------------------------
            warning off;
            ReadFunc = @(X)load( X );                                       %#ok<LOAD>
            obj.Ds = datastore( RootDir, 'FileExtensions', obj.Fileformat,...
                'IncludeSubfolders', true, 'Type', 'file', 'ReadFcn',...
                ReadFunc );
            obj.Signals = obj.readSignals();
            warning on;
        end % oxfordRateTestData
        
        function obj = extractData( obj )
            %--------------------------------------------------------------
            % Extract data from the datastore & write to the data table
            %
            % obj = obj.extractData();
            %--------------------------------------------------------------
            obj = obj.resetDs();
            obj.Data = table.empty;
            N = obj.NumFiles;
            for Q = 1:N
                %----------------------------------------------------------
                % Fetch the necessary data one file at a time and append to
                % a data table for export
                %----------------------------------------------------------
                Msg = sprintf( 'Extracting data from file %3.0f of %3.0f',...
                    Q, N );
                try
                    waitbar( ( Q / N ), W, Msg );
                catch
                    W = waitbar( ( Q / N ), Msg );
                end
                %----------------------------------------------------------
                % Read the current file
                %----------------------------------------------------------
                T = obj.readDs();
                Flds = string( fieldnames( T ) );
                T = T.( Flds );
                %----------------------------------------------------------
                % Capture metadata
                %----------------------------------------------------------
                SerialNumber = obj.getSerialNumber( Q );
                Temperature = obj.getTemperature( T );
                CRate = obj.getCRate( Q );
                %----------------------------------------------------------
                % Calculate number and location of the discharge events
                %----------------------------------------------------------
                NumCyc = obj.numCycles( T, obj.Current_ );
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                Cycle = ( 1:NumCyc ).';
                %----------------------------------------------------------
                % Calculate the discharge capacity
                %----------------------------------------------------------
                DischargeCapacity = ( T.( obj.Capacity_ )( Start ) -....
                    T.( obj.Capacity_ )( Finish - 1 ) );
                %----------------------------------------------------------
                % Write the curreent data to a summary data and append it
                % to the data table
                %----------------------------------------------------------
                SerialNumber = repmat( SerialNumber, NumCyc, 1 );
                Temperature = repmat( Temperature, NumCyc, 1 );
                CRate = repmat( CRate, NumCyc, 1 );
                Facility = string( repmat( obj.Facility, NumCyc, 1 ) );     %#ok<PROP>
                BatteryName = repmat( obj.Battery, NumCyc, 1 );
                T = table( BatteryName, SerialNumber, CRate, Cycle,...
                    Facility, Temperature, DischargeCapacity );             %#ok<PROP>
                if isempty( obj.Data )
                    obj.Data = T;
                else
                    obj.Data = vertcat( obj.Data, T );
                end
            end
            %--------------------------------------------------------------
            % Define the units
            %--------------------------------------------------------------
            obj.Data.Properties.VariableUnits = cellstr( [ "NA", "NA",...
                "[Ah]", "[#]", "NA", "[Deg C]", "Ah" ] );
            close( W );
        end % extractData
    end % constructor and ordinary methods
    
    methods ( Access = protected )  
        function T = getTemperature( obj, Q, Str )  
            %--------------------------------------------------------------
            % Parse the ageing temperature
            %
            % T = obj.getTemperature( Q, Str );
            %
            % Input Arguments:
            %
            % Q   --> Data table
            % Str --> Name of temeperature channel {"Temp1"}
            %--------------------------------------------------------------
            if ( nargin < 3 )
                Str = "Temp1";                                              % Apply the default
            else
                Str = string( Str );
            end
            Ok = obj.channelPresent( Str );
            if Ok
                T = round( median( Q.( Str ) ) );
                if ( T < 35 )
                    T = 25;
                else
                    T = 45;
                end
            else
                error( "Channel %s not present in data file", Str );
            end
        end % getTemperature
        
        function C = getCRate( obj, Q )
            %--------------------------------------------------------------
            % Fetch the C-rate data for the Qth file
            %
            % C = obj.getCrate( Q );
            %
            % Input Arguments:
            %
            % Q   --> pointer to file
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ Q };
            Fname = string( Fname );
            C = extractBetween( Fname, "RateTest_", "C_" );
            C = double( C );
        end % getCrate
        
        function SerialNumber = getSerialNumber( obj, Q )
            %--------------------------------------------------------------
            % Parse the battery serial number information
            %
            % SerialNumber = obj.getSerialNumber( Q );
            %
            % Input Arguments:
            %
            % Q   --> pointer to file
            %--------------------------------------------------------------
            L = obj.Ds.Files{ Q };
            SerialNumber = string( extractBetween( L, "OXF_", "_Rate" ) );
        end % getSerialNumber
    end % protected methods    
    
    methods ( Access = private )
        function S = readSignals( obj )
            %--------------------------------------------------------------
            % Read the signals contained in the data base and return as a
            % string array
            %
            % S = obj.readSignals();
            %--------------------------------------------------------------
            obj = obj.resetDs();
            T = obj.readDs();
            S = string( fieldnames( T ) );
            T = T.( S );
            S = string( T.Properties.VariableNames );
        end % readSignals  
    end % private methods
    
    methods ( Static = true )
       function N = numCycles( T, EventChannel )
            %--------------------------------------------------------------
            % Return number of cycles
            %
            % N = obj.numCycles( T, EventChannel );
            %
            % Input Arguments:
            %
            % T             --> (table) data table
            % EventChannel  --> (string) Name of channel defining event
            %
            % Output Arguments:
            %
            % N             --> Number of cycles
            %--------------------------------------------------------------
            S = sign( T.( EventChannel ) );
            S( S > 0 ) = 0;
            S = diff( S );
            N = sum( S < 0 );
        end % numCycles  
               
        function [ Start, Finish ] = locEvents( T, EventChannel )
            %--------------------------------------------------------------
            % Locate start and finish of discharge events
            %
            % [ Start, Finish ] = obj.locEvents( T, , EventChannel );
            %
            % Input Arguments:
            %
            % T             --> (table) data table
            % EventChannel  --> (string) Name of channel defining event
            %--------------------------------------------------------------
            S = sign( T.( EventChannel ) );
            S( S > 0 ) = 0;
            S = diff( S );
            Start = find( S < 0, numel( S ), 'first' );
            Start = Start + 1;
            Finish = find( S > 0, numel( S ), 'first' );
            Finish = Finish + 1;
        end % locEvents
    end % Static methods
end % rateTestDataImporter