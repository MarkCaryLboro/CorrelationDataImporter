classdef lancasterPulseTestData < pulseTestDataImporter
    % Concrete pulse test data interface for facility correlation analysis
    % for Lancaster BATLAB data
    
    properties ( Constant = true )
        Fileformat            string                = ".csv"                % Supported input formats
        Tester                string                = "Novonix"             % Type of battery tester
        Facility              correlationFacility   = "Lancaster"           % Facility name
    end % abstract & constant properties
    
    properties ( SetAccess = protected )
        Current               string                = "Current (A)"         % Name of current channel
        Voltage               string                = "Potential (V)"       % Name of voltage channel
        Capacity              string                = "Capacity (Ah)"       % Name of capacity channel
        DischgCurrent         double          = -1.67                       % Discharge current 
    end % protected properties
    
    methods
        function obj = lancasterPulseTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % lancasterPulseTestData constructor. Imports correlation pulse
            % test data and converts it to standard format
            %
            % obj = lancasterPulseTestData( BatteryId, RootDir );
            %
            % Input Arguments:
            %
            % BatteryId         --> (string) Name of battery {"LGM50"}
            % RootDir           --> (string) Root directory where data is  
            %                       held. User is prompted for the 
            %                       directory if empty
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
            obj.Ds = tabularTextDatastore( RootDir, 'FileExtensions', ...
                        obj.Fileformat, 'IncludeSubfolders', true, ...
                        'OutputType', "table", 'TextType', "string" );
            obj.Ds.ReadSize = 50000;        
            [ obj.Ds.NumHeaderLines,  obj.Signals ] = obj.numHeaderLines();
            warning on;
        end % constructor
        
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
                % Read the current file
                %----------------------------------------------------------
                T = obj.readDs();
                %----------------------------------------------------------
                % Calculate number and location of the pulses
                %----------------------------------------------------------
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                NumCyc = numel( Start );
                %----------------------------------------------------------
                % Calculate the state of charge
                %----------------------------------------------------------
                SoC = obj.calcSoC( T, Start, Finish );
                %----------------------------------------------------------
                % Calculate the discharge internal resistance values
                %----------------------------------------------------------
                [ DischargeIR, ChargeIR, DV, DI, CV, CI ] = obj.calcIR( T,...
                                                           Start, Finish );
                %----------------------------------------------------------
                % Write the curreent data to a summary data and append it 
                % to the data table
                %----------------------------------------------------------
                SerialNumber = repmat( SerialNumber, NumCyc, 1 );
                Temperature = repmat( Temperature, NumCyc, 1 );
                Facility = string( repmat( obj.Facility, NumCyc, 1 ) );     %#ok<PROP>
                BatteryName = repmat( obj.Battery, NumCyc, 1 );
                T = table( BatteryName, SerialNumber, Facility,...
                           Temperature, SoC, DischargeIR, ChargeIR, DV, DI,...
                           CV, CI );                                        %#ok<PROP>
                if isempty( obj.Data )
                    obj.Data = T;
                else
                    obj.Data = vertcat( obj.Data, T );
                end
            end
            %--------------------------------------------------------------
            % Define the units
            %--------------------------------------------------------------
            obj.Data.Properties.VariableUnits = cellstr( [ "NA", "NA", "NA",...
                            "[Deg C]", "[%]", "[Ohms]", "[Ohms]" , "[V]", "[A]",...
                            "[V]", "[A]" ] );
            close( W );
        end % extractData
        
        function obj = setDischgCurrent( obj, Dc )
            %--------------------------------------------------------------
            % Set the value of the discharge current
            %
            % obj = obj.setDischgCurrent( Dc );
            %
            % Input Arguments:
            %
            % Dc    --> Discharge current [A]
            %--------------------------------------------------------------
            arguments
                obj     (1,1)   lancasterPulseTestData
                Dc      (1,1)   double                  { mustBeNegative( Dc ) } = -1.67
            end
            obj.DischgCurrent = Dc;
        end % setDischgCurrent
    end % ordinary & constructor methods
    
    methods ( Access = protected )
        function T = getTemperature( obj, Q, Str )  
            %--------------------------------------------------------------
            % Parse the ageing temperature
            %
            % T = obj.getTemperature( Q, Str );
            %
            % Input Arguments:
            %
            % Q   --> pointer to file
            % Str --> search string. Line to find begins with this string
            %--------------------------------------------------------------
            if ( nargin < 3 )
                Str = "Cell: ";                                             % Apply the default
            end
            T = obj.searchHeader( Q, Str );
            T = replace( T, Str, "" );
            D = extractBetween( T, "_", "C_" );
            D = extractAfter( D, strlength( D ) - 2 );
            if isempty( D ) || contains( D, "_" )
                %----------------------------------------------------------
                % Alternative format
                %----------------------------------------------------------
                D = extractBefore( T, "deg" );
                D = extractAfter( D, strlength( D ) - 2 );
            end
            T = double( D );
        end % getTemperature
        
        function SerialNumber = getSerialNumber( obj, Q, Str )
            %--------------------------------------------------------------
            % Parse the battery serial number information
            %
            % SerialNumber = obj.getSerialNumber( Q, Str );
            %
            % Input Arguments:
            %
            % Q   --> pointer to file
            % Str --> search string. Line to find begins with this string
            %--------------------------------------------------------------
            if ( nargin < 3 )
                Str = "Cell: ";                                             % Apply the default
            end
            L = obj.searchHeader( Q, Str );
            L = replace( L, Str, "" );
            SerialNumber = string( extractBetween( L, "Cell", "_" ) );
        end % getSerialNumber
    end % protected methods
    
    methods ( Access = private )
        function L = searchHeader( obj, Q, Str )
            %--------------------------------------------------------------
            % search the header of the Qth file in the datastore for the
            % line beginning with the string Str
            %
            % L = obj.searchHeader( Q, Str );
            %
            % Input Arguments:
            %
            % Q     --> Pointer to file to search
            % Str   --> Search string. Line to find starts with this.
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ Q };
            Fid = fopen( Fname );
            Ok = false;
            while ~Ok
                %----------------------------------------------------------
                % Search for the line beginning with Str
                %----------------------------------------------------------
                L = string( fgetl( Fid ) );
                Ok = startsWith( L, Str, 'IgnoreCase', true );
            end
            fclose( Fid );                                                  % close the file
        end % searchHeader
        
        function [ N, Channels ] = numHeaderLines( obj )
            %--------------------------------------------------------------
            % Find number of header lines in the file and the list of data
            % channels.
            %
            % [ N, Channels ] = obj.numHeaderLines();
            %
            % Output Arguments:
            %
            % N
            % Channels  --> List of available channels (string)
            %--------------------------------------------------------------
            Fname = obj.Ds.Files{ 1 };
            [ T, ~, N ] =importdata( Fname );
            Channels = string( T.textdata( N, : ) );
            N = N - 1;
        end % numHeaderLines
    end % private methods
    
    methods ( Static = true, Access = protected )
    end % static and protected methods
end % lancasterPulseTestData