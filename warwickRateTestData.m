classdef warwickRateTestData < rateTestDataImporter
    % Concrete rate test data interface for facility correlation analysis
    % for Warwick data    
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Novonix"             % Type of battery tester
        Facility              correlationFacility   = "Warwick"             % Facility name
    end % abstract & constant properties   
    
    properties ( SetAccess = protected )
        Current               string                = "Current (A)"         % Name of current channel
        Capacity              string                = "Capacity (Ah)"       % Name of capacity channel
    end % protected properties    
    
    methods
        function obj = warwickRateTestData( BatteryId, RootDir )
            %--------------------------------------------------------------
            % warwickRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = warwickRateTestData( ( BatteryId, RootDir ) );
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
        end
        
        function obj = extractData( obj, FileName )
            %--------------------------------------------------------------
            % Extract data from the datastore & write to the data table
            %
            % obj = obj.extractData( FileName );
            %
            % 
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
                CRate = obj.getCrate( Q ); 
                %----------------------------------------------------------
                % Read the current file
                %----------------------------------------------------------
                T = obj.readDs();
                %----------------------------------------------------------
                % Calculate number and location of the discharge events
                %----------------------------------------------------------
                NumCyc = obj.numCycles( T, obj.Current_ );
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                Cycle = ( 1:NumCyc ).';
                %----------------------------------------------------------
                % Calculate the discharge capacity
                %----------------------------------------------------------
                DischargeCapacity = T{ Start, obj.Capacity_ } -....
                                    T{ Finish, obj.Capacity_ };
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
                           Facility, Temperature, DischargeCapacity );      %#ok<PROP>
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
        
        function setCapacityChannel( obj )
        end % setCapacityChannel
        
        function setCurrentChannel( obj )
        end % setCapacityChannel
        
    end
    
    methods ( Access = protected )
        function S = getSerialNumber( obj, Q, Str )   
            %--------------------------------------------------------------
            % Fetch serial number of current file
            % 
            % S = obj.getSerialNumber( Q, Str );
            %
            % Input Arguments:
            %
            % Q   --> pointer to file
            % Str --> search string.
            %--------------------------------------------------------------
            if ( nargin < 3 )
                Str = "Cell";
            end
            [ ~, Fname ] = fileparts( obj.Ds.Files{ Q } );
            S = string( extractBetween( Fname, Str, "_" ));
        end % getSerialNumber
        
        function T = getTemperature( obj, Q, Str )                                   
            % Fetch the temperature setting
        end % getTemperature
        
        function C = getCrate( obj, Q, Str ) 
            % Fetch the c-rate data
        end % getCrate
    end % protected methods
    
    methods ( Static = true, Hidden = true )
        function D = calcDuration( DateTime ) 
            % Convert timestamps to durations  
        end %calcDuration
        
        function N = numCycles( T )                                                  
            % Return number of cycles  
        end % numCycles
        
        function [ Start, Finish ] = locEvents( C )  
            % Return start and finish of discharge events
        end % locEvents
    end % Static & hidden methods
end % warwickRateTestData