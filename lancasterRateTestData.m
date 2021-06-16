classdef lancasterRateTestData < rateTestDataImporter
    % Concrete rate test data interface for facility correlation analysis
    % for Lancaster BATLAB data
    
    properties ( Constant = true )
        Fileformat            string                = ".csv"                % Supported input formats
        Tester                string                = "Novonix"             % Type of battery tester
    end % abstract & constant properties
       
    properties ( SetAccess = protected )
        Current               string                = "Current (A)"         % Name of current channel
        Capacity              string                = "Capacity (Ah)"       % Name of capacity channel
    end % 
    
    methods
        function obj = lancasterRateTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % lancasterRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = lancasterRateTestData( RootDir );
            %
            % Input Arguments:
            %
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
            obj.Ds = tabularTextDatastore( RootDir, 'FileExtensions', ...
                        obj.Fileformat, 'IncludeSubfolders', true, ...
                        'OutputType', "table", 'TextType', "string" );
            obj.Ds.ReadSize = 50000;        
            [ obj.Ds.NumHeaderLines,  obj.Signals ] = obj.numHeaderLines();
            warning on;
        end
        
        function obj = setCurrentChannel( obj, Current )
            %--------------------------------------------------------------
            % Define current channel name
            %
            % obj = obj.setCurrentChannel( Current );
            %
            % Input Arguments:
            %
            % Current   --> (string) Name of current channel
            %--------------------------------------------------------------
            arguments
                obj         lancasterRateTestData
                Current     string                  { mustBeNonEmpty( Current ) }
            end
            Current = replace( Current, "(", "_" );
            Current = replace( Current, ")", "_" );
            Ok = obj.channelPresent( Current );
            if Ok
                obj.Current = Current;
            end
        end % setCurrentChannel
        
        function obj = setCapacityChannel( obj, Capacity )
            %--------------------------------------------------------------
            % Define capacity channel name
            % obj = obj.setCurrentChannel( Current );
            %
            % Input Arguments:
            %
            % Capacity   --> (string) Name of capacity channel
            %--------------------------------------------------------------
            arguments
                obj         lancasterRateTestData
                Capacity    string                  { mustBeNonEmpty( Capacity ) }
            end
            Ok = obj.channelPresent( Capacity );
            if Ok
                obj.Capacity = Capacity;
            end
        end
    end % constructor and ordinary methods
    
    methods 
    end % get/set methods
    
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
                Str = "Cell:";                                              % Apply the default
            end
            T = obj.searchHeader( Q, Str );
            T = replace( T, Str, "" );
            T = extractBefore( T, "deg" );
            T = extractAfter( T, strlength( T ) - 2 );
            T = double( T );
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
                Str = "Cell:";                                              % Apply the default
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
    
    methods ( Static = true )
        function D = calcDuration( DateTime )      
            %--------------------------------------------------------------
            % Calculate the test durations
            %
            % D = obj.calcDuration( DateTime );
            %
            % Input Arguments:
            %
            % DateTime  --> (datetime) time stamp vector for test data
            %--------------------------------------------------------------
            arguments 
                DateTime  (:,1)  datetime
            end
            D = min( DateTime );
            D = duration( DateTime - D );
        end % calcDuration
        
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
    end % static methods
end % lancasterRateTestData