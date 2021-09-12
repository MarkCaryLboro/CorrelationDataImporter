classdef (Abstract = true ) pulseTestDataImporter
    % Abstract pulse test data importer class
        
    properties ( SetAccess = protected )
        Ds                                                                  % File data store
        Signals     (1,:)     string                                        % List of available channels
        Data                  table                                         % Data table
        Battery     (1,1)     string          = "LGM50"                     % Battery name
    end % protected properties

    properties ( Abstract = true, SetAccess = protected )
        Current               string                                        % Name of current channel
        Voltage               string                                        % Name of voltage channel
    end % Abstract & protected properties    
    
    properties ( Constant = true, Abstract = true )
        Fileformat            string                                        % Supported input formats
        Tester                string                                        % Type of battery tester
        Facility              correlationFacility                           % Facility name
    end % abstract & constant properties    
    
    properties ( SetAccess = protected, Dependent = true )
        NumFiles                                                            % Number of files in datastore
    end % Dependent properties
    
    properties ( Access = protected, Dependent = true )
        Current_              string
        Voltage_              string
    end    
    
    methods ( Abstract = true )
        obj = extractData( obj, varagin )                                   % Extract data from datastore
    end % Abstract methods signatures
    
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
        
        function obj = setVoltageChannel( obj, Voltage )
            %--------------------------------------------------------------
            % Define voltage channel name
            %
            % obj = obj.setVoltageChannel( Voltage );
            %
            % Input Arguments:
            %
            % Voltage   --> (string) Name of voltage channel
            %--------------------------------------------------------------
            arguments
                obj         lancasterRateTestData
                Voltage     string                  { mustBeNonEmpty( Voltage ) }
            end
            Ok = obj.channelPresent( Voltage );
            if Ok
                obj.Capacity = Voltage;
            end
        end % setVoltageChannel
        
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
    end % ordinary methods    
    
    methods
        function C = get.Current_( obj )
            % Return parsed current channel
            C = obj.parseChannelName( obj.Current );
        end       
        
        function C = get.Voltage_( obj )
            % Return parsed current channel
            C = obj.parseChannelName( obj.Voltage );
        end
    end % GET/SET Methods
    
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
            Name = replace( Name, "-", "" );
        end % parseChannelName
        
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
        
        function S = interpData( S )
            %--------------------------------------------------------------
            % Reinterpolate data to remove NaNs
            %
            % S = obj.interpData( S );
            %
            % Input Arguments:
            %
            % S     --> Data structure
            %--------------------------------------------------------------
            Names = string( fieldnames( S ) );
            N = numel( Names );
            for Q = 1:N
                %----------------------------------------------------------
                % If any nans present re-interpolate
                %----------------------------------------------------------
                if any( isnan( S.( Names{ Q } ) ) )
                    D = S.( Names{ Q } );
                    X = ( 1:numel( D ) ).';
                    Idx = ~isnan( D );
                    D = D( Idx );
                    S.( Names{ Q } ) = interp1( X( Idx ), D, X, 'linear',...
                                           'extrap' );
                end
            end
        end % interpData        
        
        function [LastRow, LastCol ] = findLast( ExcelFile, SheetName )
            import correlationDataStore.findLastRow
            [LastRow, LastCol ] = findLastRow( ExcelFile, SheetName );
        end % findLastRow
        
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
    end % protected static methods
end % pulseTestDataImporter