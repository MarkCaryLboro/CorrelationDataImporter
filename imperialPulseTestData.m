classdef imperialPulseTestData < pulseTestDataImporter
    % Concrete pulse test data interface for facility correlation analysis
    % for Imperial data
    
    properties ( SetAccess = protected )
        Current               string                = "I_mA"                % Name of current channel
        Capacity              string                = "Capacity_mAh"        % Name of capacity channel
        Voltage               string                = "Ecell_V"             % Name of voltage channel
        DischgCurrent         double                = -1.67e3               % Discharge current 
        PulseTime             double                = 10                    % Required pulse time [s]
        Time                  string                = "time_s"              % Name of time channel
        CF                    double                = 1                     % Time signal to seconds c.f.
    end % protected properties 
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Biologic"            % Type of battery tester
        Facility              correlationFacility   = "Imperial"            % Facility name
    end % abstract & constant properties
    
    methods
        function obj = imperialPulseTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % imperialPulseTestData constructor. Imports correlation pulse
            % test data and converts it to standard format
            %
            % obj = imperialPulseTestData( BatteryId, RootDir );
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
                RootDir = uigetdir( cd, "Select root directory containing Imperial rate test data" );
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
                % Read the current file
                %----------------------------------------------------------
                T = obj.readDs();
                T.data = obj.interpData( T.data );
                T.data = struct2table( T.data );
                %----------------------------------------------------------
                % Capture metadata
                %----------------------------------------------------------
                SerialNumber = obj.getSerialNumber( Q );
                try
                    Temperature = obj.getTemperature( T.data );
                catch
                    Temperature = nan;
                end
                %----------------------------------------------------------
                % Calculate number and location of the discharge events
                %----------------------------------------------------------
                [ Start, Finish ] = obj.locEvents( T.data, obj.Current_ );
                %----------------------------------------------------------
                % Remove the last start pulse which looks dodgey
                %----------------------------------------------------------
                Start = Start( 1:( end - 1 ) );
                NumCyc = numel( Start );
                %----------------------------------------------------------
                % Calculate the state of charge
                %----------------------------------------------------------
                SoC = obj.calcSoC( T.data, Start, Finish );
                SoC = cumsum( SoC );
                SoC = 1 - SoC;
                %----------------------------------------------------------
                % Calculate the discharge internal resistance values
                %----------------------------------------------------------
                [ DischargeIR, ChargeIR, DV, DI, CV, CI ] = obj.calcIR( T.data,...
                    Start, Finish );
                DischargeIR = obj.iRisNanOrZero( DischargeIR );
                ChargeIR = obj.iRisNanOrZero( ChargeIR );
                %----------------------------------------------------------
                % Correct the units
                %----------------------------------------------------------
                DI = DI/1000;
                CI = CI/1000;
                DischargeIR = DischargeIR * 1000;
                ChargeIR = ChargeIR * 1000;
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
            SerialNumber = replace( SerialNumber, " ", "_" );
        end % getSerialNumber
        
        function T = getTemperature( obj, Data, SigName )                   %#ok<INUSL>
            %--------------------------------------------------------------
            % Return the environmental chamber test temperature
            %
            % T = obj.getTemperature( Data, SigName );
            %
            % Input Arguments:
            %
            % Data      --> (struct) Raw data structure.
            % SigName   --> (string) Name of temperature channel. Default
            %                        is "Temperature_degC".
            %--------------------------------------------------------------
            if ( nargin < 3 ) || isempty( SigName )
                SigName = "Temperature_degC";
            else
                SigName = string( SigName );
            end
            T = median( Data.( SigName ) );
        end % getTemperature        
    end % private methods
end

