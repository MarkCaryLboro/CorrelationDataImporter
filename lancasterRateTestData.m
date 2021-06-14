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
        function obj = lancasterRateTestData( RootDir )
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
            if ( nargin < 1 ) || isempty( RootDir )
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
            Name = obj.Ds.Files{ Q };
            [ ~, Name ] = fileparts( Name );
            SerialNumber = string( extractBetween( Name, "Cell", "_" ) );
        end
    end % protected methods
    
    methods ( Access = private )
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