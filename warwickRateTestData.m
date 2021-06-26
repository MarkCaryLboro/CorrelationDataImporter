classdef warwickRateTestData < rateTestDataImporter
    % Concrete rate test data interface for facility correlation analysis
    % for Warwick data    
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Bitrode"             % Type of battery tester
        Facility              correlationFacility   = "Warwick"             % Facility name
    end % abstract & constant properties   
    
    properties ( SetAccess = protected )
        Current               string                = "Current"             % Name of current channel
        Capacity              string                = "AhAccu"              % Name of capacity channel
    end % protected properties    
    
    methods
        function obj = warwickRateTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % warwickRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = warwickRateTestData( BatteryId, RootDir );
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
            warning on;        
        end % Class constructor
        
        function obj = extractData( obj, FileName )
            %--------------------------------------------------------------
            % Extract data from the datastore & write to the data table
            %
            % obj = obj.extractData( FileName );
            %
            % Input Arguments:
            %
            % FileName  --> (string) Full file specification for index file
            %               If empty user will be prompted for the file
            %               name.
            %--------------------------------------------------------------
            if ( nargin < 2 ) || ~isfile( FileName )
                [ FileName, Fpath ] = uigetfile( ".xlsx",...
                    "Select rate test index file", "Rate_Crate&Temp.xlsx",...
                    'MultiSelect', 'off' );
               FileName = fullfile( Fpath, FileName );
            end
            if isfile( FileName )
                Idx = obj.makeIndexTable( FileName );
            else
                error( 'Must Supply a Valid File Name' );
            end
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
                SerialNumber = string( Idx.SerialNumber( Q ) );
                Temperature = Idx.Temperature( Q );
                CRate = string( Idx.CRate{ Q } ); 
                CRate = double( replace( CRate, "C", "" ) );
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
                DischargeCapacity = T.data.( obj.Capacity_ )( Start ) -....
                                    T.data.( obj.Capacity_ )( Finish );
                %----------------------------------------------------------
                % Write the curreent data to a summary data and append it 
                % to the data table
                %----------------------------------------------------------
                SerialNumber = repmat( SerialNumber, NumCyc, 1 );
                Temperature = repmat( Temperature, NumCyc, 1 );
                CRate = repmat( CRate, NumCyc, 1 );
                Facility = string( repmat( obj.Facility, NumCyc, 1 ) );      %#ok<PROPLC>
                BatteryName = repmat( obj.Battery, NumCyc, 1 );
                T = table( BatteryName, SerialNumber, CRate, Cycle,...
                           Facility, Temperature, DischargeCapacity );       %#ok<PROPLC>
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
    end % protected methods
    
    methods ( Access = private )
    end % private methods
    
    methods ( Static = true, Hidden = true )
        function T = makeIndexTable( Fname )
            %--------------------------------------------------------------
            % Generate the index table necessary for assigning the settings
            % to the data
            %
            % T = obj.makeIndexTable( Fname );
            % 
            % Input Arguments:
            %
            % Fname     --> Full file specification for index file
            %--------------------------------------------------------------
            [ ~, ~, T ] = xlsread( Fname, 1 );
            Vars = string( T( 1, : ) );
            %--------------------------------------------------------------
            % Use standard names
            %--------------------------------------------------------------
            Idx = strcmpi( "C_rate", Vars );
            Vars( Idx ) = "CRate";
            Idx = strcmpi( "CellNumber", Vars );
            Vars( Idx ) = "SerialNumber";
            T = T( 2:end, : );
            T = cell2table( T );
            T.Properties.VariableNames = Vars;
        end % makeIndexTable
        
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
    end % Static & hidden methods
end % warwickRateTestData