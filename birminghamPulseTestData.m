classdef birminghamPulseTestData < pulseTestDataImporter
    % Concrete pulse test data interface for facility correlation analysis
    % for Birmingham data    
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Maccor"              % Type of battery tester
        Facility              correlationFacility   = "Birmingham"          % Facility name
    end % abstract & constant properties
       
    properties ( SetAccess = protected )
        Current               string                = "Amps"                % Name of current channel
        Capacity              string                = "Amp_hr"              % Name of capacity channel
        State                 string                = "State"               % Channel indicating cell states
        Voltage               string                = "Volts"               % Name of voltage channel
        DischgCurrent         double                = -1.667                % Discharge current 
    end % protected properties    
    
    methods
        function obj = birminghamPulseTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % birminghamRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = birminghamRateTestData( BatteryId, RootDir );
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
                RootDir = uigetdir( cd, "Select root directory containing Birmingham rate test data" );
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
        
        function obj = setState( obj, Name )
            %--------------------------------------------------------------
            % Set the name of the cell state channel. Default is "State"
            %
            % obj = obj.setState( Name );
            %
            % Input Arguments:
            %
            % Name  --> Name of channel in the signals list containing
            %           state data
            %--------------------------------------------------------------
            arguments
                obj     (1,1)   birminghamRateTestData
                Name    (1,1)   string                  = "State"
            end
            Ok = obj.channelPresent( Name );
            if Ok
                obj.State = Name;
            else
                warning('Cannot set "State". Signal "%s" not in the signals list',...
                        Name);
            end
        end
        
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
                T = struct2table( T.data );
                %----------------------------------------------------------
                % Set the states to enumeration
                %----------------------------------------------------------
                T.State = states( T.State );
                %----------------------------------------------------------
                % Capture metadata
                %----------------------------------------------------------
                SerialNumber = obj.getSerialNumber( Q );
                try
                    %------------------------------------------------------
                    % Try to capture temperature data from data table
                    %------------------------------------------------------
                    Temperature = obj.getTemperature( T );
                catch
                    %------------------------------------------------------
                    % Otherwise use the file name
                    %------------------------------------------------------
                    Temperature = obj.getTemperatureFname( Q );
                end
                %----------------------------------------------------------
                % Calculate number and location of the discharge events
                %----------------------------------------------------------
                T = obj.invertDischargeCurrent( T );
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                %----------------------------------------------------------
                % Remove the last pulse which is not required
                %----------------------------------------------------------
                Start = Start( 1:( end - 1 ) );
                Finish = Finish( 1:( end - 1 ) );
                NumCyc = numel( Start );
                %----------------------------------------------------------
                % Calculate the state of charge
                %----------------------------------------------------------
                SoC = obj.calcSoC( T, Start, Finish );
                SoC = cumsum( SoC );
                SoC = 1 - SoC;
                %----------------------------------------------------------
                % Calculate the discharge internal resistance values
                %----------------------------------------------------------
                [ DischargeIR, ChargeIR, DV, DI, CV, CI ] = obj.calcIR( T,...
                    Start, Finish );
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
            % Set the value of the discharge current in [mA]
            %
            % obj = obj.setDischgCurrent( Dc );
            %
            % Input Arguments:
            %
            % Dc    --> Discharge current [mA]
            %--------------------------------------------------------------
            arguments
                obj     (1,1)   imperialPulseTestData
                Dc      (1,1)   double                  { mustBeNegative( Dc ) } = -1.67e3
            end
            obj.DischgCurrent = Dc;
        end % setDischgCurrent        
    end % ordinary and constructor methods
    
    methods ( Access = protected )
        function T = getTemperatureFname( obj, Q )
            %--------------------------------------------------------------
            % Parse the temperature data from the file name
            %
            % T = obj.getTemperatureFname( Q );
            %
            %
            % Input Arguments:
            %
            % Q   --> Pointer to current file
            %--------------------------------------------------------------
            Name = obj.Ds.Files{ Q };
            if contains( Name, "25" )
                T = 25;
            else
                error('Cannot determine test temperature in file "%s"',...
                                Name );
            end
        end % getTemperatureFname
        
        function T = getTemperature( obj, DataTable, Str )  
            %--------------------------------------------------------------
            % Parse the ageing temperature from data
            %
            % T = obj.getTemperature( Q, Str );
            %
            % Input Arguments:
            %
            % DataTable     --> Data table
            % Str           --> Name of temeperature channel {"EVTempC"}
            %--------------------------------------------------------------
            if ( nargin < 3 )
                Str = "EVTempC";                                            % Apply the default
            else
                Str = string( Str );
            end
            Ok = obj.channelPresent( Str );
            if Ok
                %----------------------------------------------------------
                % Assign the temperature from measurement
                %----------------------------------------------------------
                T = median( DataTable.( Str ) );
            end
        end % getTemperature        
        
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
            SerialNumber = string( extractBetween( L, "_Cell",...
                                                      "_Pulse_Test" ) );
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
            T = T.data;
            S = string( fieldnames( T ) );
        end % readSignals  
        
        function T = invertDischargeCurrent( obj, T )
            %--------------------------------------------------------------
            % Make sure discharge currents are negative
            %
            % T = obj.invertDischargeCurrent( T );
            %
            % Input Arguments:
            %
            % T     --> Data table for the current file
            %--------------------------------------------------------------
            Idx = ( T.( obj.State )  == "D" );
            C = T.( obj.Current_ );
            C( Idx ) = -C( Idx );
            T.( obj.Current_ ) = C;
        end % invertDischargeCurrent
    end % private methods
end % classdef