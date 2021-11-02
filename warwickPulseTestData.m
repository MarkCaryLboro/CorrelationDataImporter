classdef warwickPulseTestData < pulseTestDataImporter
    % Concrete pulse test data interface for facility correlation analysis
    % for Warwick data    
    
    properties ( Constant = true )
        Fileformat            string                = ".csv"                % Supported input formats
        Tester                string                = "Digatron"            % Type of battery tester
        Facility              correlationFacility   = "Warwick"             % Facility name
    end % abstract & constant properties   
    
    properties ( SetAccess = protected )
        Current               string                = "Current"             % Name of current channel
        Capacity              string                = "AhAccu"              % Name of capacity channel
        Voltage               string                = "Voltage"             % Name of voltage channel
        DischgCurrent         double          = -1.67                       % Discharge current 
    end % protected properties    
    
    methods
        function obj = warwickPulseTestData( BatteryId, RootDir )
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
                RootDir = uigetdir( cd, "Select root directory containing Warwick pulse test data" );
            elseif ~isfolder( RootDir )
                error( '"%s" is not a valid folder', RootDir );
            end
            RootDir = string( RootDir );
            %--------------------------------------------------------------
            % Create data store
            %--------------------------------------------------------------
            warning off
            ReadFcnFh = @( X )obj.customreader( X );
            obj.Ds = fileDatastore( RootDir, 'FileExtensions', ...
                        obj.Fileformat, 'IncludeSubfolders', true, ...
                        'ReadFcn', ReadFcnFh);
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
                % Read the current file
                %----------------------------------------------------------
                T = obj.readDs();
                %----------------------------------------------------------
                % Capture metadata
                %----------------------------------------------------------
                SerialNumber = obj.getSerialNumber( obj.Ds.Files( Q ) );
                Temperature = obj.getTemperature( T );
                %--------------------------------------------------------------
                % Calculate number and location of the pulses
                %--------------------------------------------------------------
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                %--------------------------------------------------------------
                % Remove the last pulse which looks dodgey
                %--------------------------------------------------------------
                Start = Start( 1:( end - 1 ) );
                Finish = Finish( 1:( end - 1 ) );
                NumCyc = numel( Start );
                %--------------------------------------------------------------
                % Calculate the state of charge
                %--------------------------------------------------------------
                SoC = obj.calcSoC( T, Start, Finish );
                %--------------------------------------------------------------
                % Calculate the discharge internal resistance values
                %--------------------------------------------------------------
                [ DischargeIR, ChargeIR, DV, DI, CV, CI ] = obj.calcIR( T,...
                    Start, Finish, 2 );
                %----------------------------------------------------------
                % Write the current data to a summary data and append it
                % to the data table
                %----------------------------------------------------------
                SerialNumber = repmat( SerialNumber, NumCyc, 1 );
                Temperature = repmat( Temperature, NumCyc, 1 );
                Facility = string( repmat( obj.Facility, NumCyc, 1 ) );     %#ok<PROP>
                BatteryName = repmat( obj.Battery, NumCyc, 1 );
                T = table( BatteryName, SerialNumber, Facility,...
                    Temperature, SoC, DischargeIR, ChargeIR, DV, DI,...
                    CV, CI );                                               %#ok<PROP>
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
                "[Deg C]", "[%]", "[Ohms]", "[Ohms]" , "[V]",...
                "[A]", "[V]", "[A]" ] );
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
                obj     (1,1)   warwickPulseTestData
                Dc      (1,1)   double                  { mustBeNegative( Dc ) } = -1.67
            end
            obj.DischgCurrent = Dc;
        end % setDischgCurrent
     end % constructor and ordinary methods
    
    
    methods ( Access = protected )       
        function T = getTemperature( obj, Data, Str )  
            %--------------------------------------------------------------
            % Parse the ageing temperature
            %
            % T = obj.getTemperature( Data, Str );
            %
            % Input Arguments:
            %
            % Data  --> Data table
            % Str   --> search string. Name of temperature channel
            %--------------------------------------------------------------
            if ( nargin < 3 )
                Str = "LogTemp001";                                         % Apply the default
            end    
            T = Data.( Str );
            T = T( ~isnan( T ) );
            T = round( median( T ) );
        end % getTemperature
        
        function T = customreader( obj, Fname )
            %--------------------------------------------------------------
            % Custom reader file for Warwick pulse test data and return a
            % table of data
            %
            % T = obj.customreader( Fname );
            %
            % Input Arguments:
            %
            % Ds        --> Datastore
            % Fname     --> Current file name
            %--------------------------------------------------------------
            [ Fid, Msg ] = fopen( Fname, "r" );
            %--------------------------------------------------------------
            % Check for an open error and print the msg
            %--------------------------------------------------------------
            assert( ( Fid ~= -1 ), Msg );
            %--------------------------------------------------------------
            % Fetch the data signal names
            %--------------------------------------------------------------
            Signals = obj.getSignals( Fid );
            %--------------------------------------------------------------
            % Fetch the signal units
            %--------------------------------------------------------------
            Units = obj.getUnits( Fid );
            %--------------------------------------------------------------
            % Find the start of the data block
            %--------------------------------------------------------------
            N = obj.numberOfHeaderLines( Fid );
            %--------------------------------------------------------------
            % Find the end of the file & generate a range vector
            %--------------------------------------------------------------
            [ LastRow, LastCol ] = obj.findLast( Fname, 1 );
            LastCol = string( char( 65 + LastCol - 1 ) );
            XLrange = strjoin( [ "$A", N + 3 ], "$" );
            XLrange = strjoin( [ XLrange, ":" ], "" );
            XLrange = strjoin( [ XLrange, "$", LastCol ], "" );
            XLrange = strjoin( [ XLrange, LastRow ], "$" );
            %--------------------------------------------------------------
            % Read in the data as a table
            %--------------------------------------------------------------
            [ ~, ~, T ] = xlsread( Fname, 1, XLrange );
            T = cell2table( T );
            T.Properties.VariableNames = Signals;
            T.Properties.VariableUnits = Units;
        end % customreader    
        
        function SoC = calcSoC( obj, T, Start, Finish )
            %--------------------------------------------------------------
            % Calculate the event state of charge
            %
            % Soc = obj.calcSoC( T, Start, Finish );
            %
            % Input Arguments:
            %
            % T         --> (table) data table
            % Start     --> (double) start of discharge events
            % Finish    --> (double) finish of discharge events
            %--------------------------------------------------------------
            N = numel( Start );                                             % Number of cycles
            C = T.( obj.Capacity_ );                                        % Capacity data
            MaxCap = max( C );                                              % Maximum capacity
            SoC = zeros( N, 1 );                                            % Define storage
            for Q = 1:N
                %----------------------------------------------------------
                % Calculate the SoC
                %----------------------------------------------------------
                if ( Q < N )
                    S = min( C( ( Finish( Q ) ):Start( Q + 1 ) ) );
                else
                    S = C( Finish( Q ) + 1 );
                end
                SoC( Q ) = ( MaxCap + ( Q * S ) ) / MaxCap;
            end
        end % calcSoC    
    end % protected methods
    
    methods ( Access = private )
    end % private methods
    
    methods ( Static = true, Access = protected )    
        function N = numberOfHeaderLines( Fid, SearchString )
            %--------------------------------------------------------------
            % Return the number of header lines
            %
            % N = obj.numberOfHeaderLines( Fid, SearchString );
            %
            % Input Arguments:
            %
            % Fid           --> handle to current file
            % SearchString  --> String to search for. This marks the end of
            %                   the header lines {"Step"}
            %--------------------------------------------------------------
            if ( nargin < 2 )
                SearchString = "Step";                                      % Apply default
            end
            frewind( Fid );                                                 % Rewind the file to the begiining
            StopFlg = false;
            N = 0;
            while ~StopFlg
                CurLine = fgetl( Fid );
                N = N + 1;
                StopFlg = contains( CurLine, SearchString );
            end
        end
        
        function SerialNumber = getSerialNumber( Fname )
            %--------------------------------------------------------------
            % Parse the battery serial number information
            %
            % SerialNumber = obj.getSerialNumber( Fname );
            %
            % Input Arguments:
            %
            % Fname   --> (string) name to file
            %--------------------------------------------------------------
            SerialNumber = string( extractBetween( Fname, "Cell", "_MSM" ) );
        end % getSerialNumber        
        
        function U = getUnits( Fid )
            %--------------------------------------------------------------
            % Return the units string
            %
            % U = obj.c( Fid );
            %
            % Input Arguments:
            %
            % Fid   --> handle to current file
            %--------------------------------------------------------------
            CurLine = fgetl( Fid );
            %--------------------------------------------------------------
            % Return the signal names
            %--------------------------------------------------------------
            Idx = strfind(CurLine,",");
            CurLine = CurLine( 1:( Idx( end ) - 1 ) );
            N = numel( Idx );
            U = string.empty( 0, N );
            for Q = 1:N
                if Q == 1
                    Start = 1;
                else
                    Start = Idx( Q - 1 ) + 1;
                end
                Finish = Idx( Q ) - 1;
                U( Q ) = string( CurLine( Start:Finish ) );
            end
        end % getUnits
        
        function Signals = getSignals( Fid )
            %--------------------------------------------------------------
            % Locate the start of the data block and return the list of
            % signals.
            %
            % obj.getSignals( Fid );
            %
            % Input Arguments:
            %
            % Fid   --> handle to current file
            %
            % Output Arguments:
            %
            % Signals   --> (string) list of data signals in the file
            %--------------------------------------------------------------
            StopFlg = false;
            Str = "Step";                                                   % Termination string
            while ~StopFlg
                CurLine = fgetl( Fid );
                StopFlg = contains( CurLine, Str );
            end
            %--------------------------------------------------------------
            % Return the signal names
            %--------------------------------------------------------------
            Idx = strfind(CurLine,",");
            CurLine = CurLine( 1:( Idx( end ) - 1 ) );
            N = numel( Idx );
            Signals = string.empty( 0, N );
            for Q = 1:N
                if Q == 1
                    Start = 1;
                else
                    Start = Idx( Q - 1 ) + 1;
                end
                Finish = Idx( Q ) - 1;
                Signals( Q ) = string( CurLine( Start:Finish ) );
            end
        end % getSignals
    end % Static & protected methods
    
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
    end % Static & hidden methods
end % warwickRateTestData