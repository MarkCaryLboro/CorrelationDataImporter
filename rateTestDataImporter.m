classdef ( Abstract = true ) rateTestDataImporter
    % Abstract rate test data interface class
    
    properties ( SetAccess = protected )
        Ds                                                                  % File data store
        Signals     (1,:)     string                                        % List of available channels
        Data                  table                                         % Data table
        Battery     (1,1)     string          = "LGM50"                     % Battery name
    end % protected properties
    
    properties ( Abstract = true, SetAccess = protected )
        Current               string                                        % Name of current channel
        Capacity              string                                        % Name of capacity channel
    end % Abstract & protected properties
    
    properties ( Constant = true, Abstract = true )
        Fileformat            string                                        % Supported input formats
        Tester                string                                        % Type of battery tester
        Facility              correlationFacility                           % Facility name
    end % abstract & constant properties
    
    properties ( SetAccess = protected, Dependent = true )
        NumFiles                                                            % Number of files in datastore
    end % Dependent properties
    
    properties ( Access = private, Dependent = true )
        Current_              string
        Capacity_             string
    end
    
    methods ( Abstract = true )
        obj = setCurrentChannel( obj, Current )                             % Define current channel name
        obj = setCapacityChannel( obj, Capacity )                           % Define capacity channel name
    end % Abstract methods signatures
    
    methods ( Access = protected, Abstract = true )
        S = getSerialNumber( obj, Q, Str )                                  % Fetch serial number of current file
        T = getTemperature( obj, Q, Str )                                   % Fetch the temperature setting
        C = getCrate( obj, Q, Str )                                         % Fetch the c-rate data
    end % Protected abstract methods signatures
    
    methods ( Static = true, Abstract = true, Hidden = true )
        D = calcDuration( DateTime )                                        % Convert timestamps to durations            
        N = numCycles( T )                                                  % Return number of cycles  
        [ Start, Finish ] = locEvents( C )                                  % Return start and finish of discharge events
    end
    
    methods
        function obj = setBattery( obj, BatteryId )
            %--------------------------------------------------------------
            % Set the battery name
            %
            % obj = obj.setBattery( BatteryId );
            %
            % Input Arguments:
            %
            % BatteryId     --> (string) battery type desgination string
            %--------------------------------------------------------------
            arguments
                obj
                BatteryId   (1,1)   string  { mustBeNonempty( BatteryId ) }
            end
            obj.Battery = upper( BatteryId );
        end % setBattery
        
        function Ok = channelPresent( obj, Channel )
            %--------------------------------------------------------------
            % Return logical value to indicate whether a user specified
            % channel name is present in the data
            %
            % Ok = obj.channelPresent( Channel );
            %
            % Input Arguments:
            %
            % Channel   --> (string) Name of channel
            %--------------------------------------------------------------
            arguments
                obj
                Channel     (1,1)   string  = string.empty
            end
            Ok = any( strcmpi( Channel, obj.Signals ) );
        end % channelPresent
        
        function [ T, Info ] = readDs( obj )
            %--------------------------------------------------------------
            % Read the next file from the datastore
            %
            % [ T, Info ] = obj.readDs();
            %
            % Output Arguments:
            %
            % T     --> (table) Extracted data.
            % Info  --> Information regarding the extracted data, including
            %           metadata.
            %--------------------------------------------------------------
            [ T, Info ] = read( obj.Ds );
        end % Read the next file from the datastore
        
        function obj = resetDs( obj )
            %--------------------------------------------------------------
            % Reset the datastore to the unread state
            %
            % obj = obj.resetDs();
            %--------------------------------------------------------------
            reset( obj.Ds );
        end % resetDs
        
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
                SerialNumber = obj.getSerialNumber( Q );
                Temperature = obj.getTemperature( Q );
                CRate = obj.getCrate( Q ); 
                T = obj.readDs();
                NumCyc = obj.numCycles( T, obj.Current_ );
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                Cycle = ( 1:NumCyc ).';
                DischargeCapacity = T{ Start, obj.Capacity_ } -....
                                    T{ Finish, obj.Capacity_ };
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
            obj.Data.Properties.VariableUnits = cellstr( [ "NA", "NA",...
                            "[Ah]", "[#]", "NA", "[Deg C]", "Ah" ] );
            close( W );
        end % extractData
        
        function export2excel( obj, Fname, Sheet )
            %--------------------------------------------------------------
            % export data to an excel file in standard format.
            %
            % obj.export2excel( Fname );
            %
            % Input Arguments:
            %
            % Fname         --> Full specification to output file
            % Sheet         --> Number of excel sheet to write to {1}
            %--------------------------------------------------------------
            arguments
                obj
                Fname       (1,1)   string    { mustBeNonempty( Fname ) }
                Sheet       (1,1)   double = 1
            end
            %--------------------------------------------------------------
            % Make sure we are exporting to an '.xlsx' file
            %--------------------------------------------------------------
            Fname = obj.makeExcelFile( Fname );
            Fpath = fileparts( Fname );
            if isempty( Fpath )
                Fpath = pwd;
                Fname = fullfile( Fpath, Fname );
            end
            if ~isfile( Fname )
                %----------------------------------------------------------
                % Write new file
                %----------------------------------------------------------
                xlswrite( Fname,...
                    [ string( obj.Data.Properties.VariableNames ); ...
                      string( obj.Data.Properties.VariableUnits)  ], ... 
                      Sheet, "A1" );
            end
            %--------------------------------------------------------------
            % Output the data to the xlsx file
            %--------------------------------------------------------------
            writetable( obj.Data, Fname, 'WriteMode', 'Append',...
                        'WriteVariableNames', false );
        end % export2excel
    end % ordinary methods
    
    methods ( Access = protected )
    end % protected methods
    
    methods
        function N = get.NumFiles( obj )
            % Return number of files in datastore
            N = numel( obj.Ds.Files );
        end 
        
        function C = get.Current_( obj )
            % Return parsed current channel
            C = obj.parseChannelName( obj.Current );
        end
        
        function C = get.Capacity_( obj )
            % Return parsed capacity channel
            C = obj.parseChannelName( obj.Capacity );
        end    end % get/set methods
    
    methods ( Access = protected )
    end % protected methods    
    
    methods ( Static = true, Access = protected )
        function ExcelFile = makeExcelFile( FileName )
            %--------------------------------------------------------------
            % Make sure the export file is an ".xlsx" file
            %
            % ExcelFile = obj.makeExcelFile( FileName )
            %
            % Input Arguments:
            %
            % FileName  --> (string) Name of file
            %--------------------------------------------------------------
            [ Fpath, ExcelFile ] = fileparts( FileName );
            ExcelFile = strjoin( [ ExcelFile, "xlsx" ], "." );
            ExcelFile = fullfile( Fpath, ExcelFile );
        end % makeExcelFile
        
        function Name = parseChannelName( Channel )
            %--------------------------------------------------------------
            % Remove spaces and parentheses
            %
            % Name = obj.parseChannelname( Channel );
            %
            % Input Arguments:
            %
            % Channel   --> (string) Name of channel to parse
            %--------------------------------------------------------------
            Name = replace( Channel, " ", "" );
            Name = replace( Name, "(", "_" );
            Name = replace( Name, ")", "_" );
        end
        
        function [LastRow, LastCol ] = findLast( ExcelFile, SheetName )
            import correlationDataStore.findLastRow
            [LastRow, LastCol ] = findLastRow( ExcelFile, SheetName );
        end % findLastRow
    end % protected static methods
end % rateTestDataImporter