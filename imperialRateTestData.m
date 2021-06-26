classdef imperialRateTestData < rateTestDataImporter
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Biologic"            % Type of battery tester
        Facility              correlationFacility   = "Imperial"            % Facility name
    end % abstract & constant properties
    
    properties ( SetAccess = protected )
        Current               string                = "Amps"                % Name of current channel
        Capacity              string                = "Amp-hr"              % Name of capacity channel
    end % protected properties
    
    methods
        function obj = imperialRateTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % imperialRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = imperialRateTestData( BatteryId, RootDir );
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
            warning off
            ReadFunc = @(X)load( X );                                       %#ok<LOAD>
            obj.Ds = datastore( RootDir, 'FileExtensions', '.mat',...
                'IncludeSubfolders', true, 'Type', 'file', 'ReadFcn',...
                ReadFunc );
            obj.Signals = obj.readSignals();
            warning on;
        end % Class constructor
        
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
                % Capture metadata
                %----------------------------------------------------------
                SerialNumber = obj.getSerialNumber( Q );
                Temperature = obj.getTemperature( Q );
                %----------------------------------------------------------
                % File naming convention changes between temperature
                % settings. So need two methods to retreive the CRate data
                %----------------------------------------------------------
                if ( Temperature == 25 )
                    CRate = obj.getCRate25( Q );
                else
                    CRate = obj.getCRate45( Q );
                end
                %----------------------------------------------------------
                % Read the current file
                %----------------------------------------------------------
                T = obj.readDs();
                T.data = obj.interpData( T.data );
                %----------------------------------------------------------
                % Calculate number and location of the discharge events
                %----------------------------------------------------------
                NumCyc = obj.numCycles( T.data, obj.Current_ );
                [ Start, Finish ] = obj.locEvents( T.data, obj.Current_ );
                Cycle = ( 1:NumCyc ).';
                %----------------------------------------------------------
                % Calculate the discharge capacity
                %----------------------------------------------------------
                DischargeCapacity = -( T.data.( obj.Capacity_ )( Start ) -....
                    T.data.( obj.Capacity_ )( Finish ) )/ 1000;
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
    end % constructor & ordinary methods
    
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
            T = T.data;
            S = string( fieldnames( T ) ).';
        end % readSignals  
        
        function C = getCRate25( obj, Q )
            %--------------------------------------------------------------
            % Return the C-Rate for the Qth cell in the datastore
            %
            % C = obj.getCRate25( Q );
            %
            % Input Arguments:
            %
            % Q     --> Pointer to current file (double)
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ Q };
            Fname = string( Fname );
            C = extractBetween( Fname, "Discharge ", "\Cell" );
            switch lower( C )
                case "0p5c"
                    C = 0.5;
                otherwise
                    C = double( replace( C, "C", "" ) );
            end
        end % getCRate25
        
        function C = getCRate45( obj, Q )
            %--------------------------------------------------------------
            % Return the C-Rate for the Qth cell in the datastore
            %
            % C = obj.getCRate45( Q );
            %
            % Input Arguments:
            %
            % Q     --> Pointer to current file (double)
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ Q };
            Fname = string( Fname );
            C = extractBetween( Fname, "deg C\", "\Cell" );
            switch lower( C )
                case lower( "Discharge 0p5 C" )
                    C = 0.5;
                otherwise
                    C = double( replace( C, "C", "" ) );
            end
        end % getCRate45
        
        function T = getTemperature( obj, Q )
            %--------------------------------------------------------------
            % Return the environmental chamber test temperature
            %
            % T = obj.getTemperature( Q );
            %
            % Input Arguments:
            %
            % Q     --> Pointer to current file (double)
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ Q };
            Fpath = fileparts( Fname );
            Fpath = string( Fpath );
            T = extractBetween( Fpath, "test\", " deg" );
            T = double( T );
        end % getTemperature
        
        function SerialNumber = getSerialNumber( obj, Q )
            %--------------------------------------------------------------
            % Return the serial number for the Qth file in the datastore
            %
            % SerialNumber = obj.getSerialNumber( Q );
            %
            % Input Arguments:
            %
            % Q     --> Pointer to current file (double)
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ Q };
            [ ~, SerialNumber ] = fileparts( Fname );
            SerialNumber = string( SerialNumber );
        end % getSerialNumber
    end % private
    
    methods ( Static = true, Hidden = true )
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
    end % static methods
end % imperialRateTestData