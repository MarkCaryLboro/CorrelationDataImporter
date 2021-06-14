classdef ( Abstract = true ) rateTestDataImporter
    % Abstract rate test data interface class
    
    properties ( SetAccess = protected )
        Ds                                                                  % File data store
        Signals     (1,:)     string                                        % List of available channels
        Data                  table                                         % Data table
    end % protected properties
    
    properties ( Abstract = true, SetAccess = protected )
        Current               string                                        % Name of current channel
        Capacity              string                                        % Name of capacity channel
    end % Abstract & protected properties
    
    properties ( Constant = true, Abstract = true )
        Fileformat            string                                        % Supported input formats
        Tester                string                                        % Type of battery tester
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
        S = getSerialNumber( obj, Q )                                       % Fetch serial number of current file
        T = getTemperature( obj, varargin )                                 % Fetch the temperature setting
    end % Protected abstract methods signatures
    
    methods ( Static = true, Abstract = true, Hidden = true )
        D = calcDuration( DateTime )                                        % Convert timestamps to durations            
        N = numCycles( T )                                                  % Return number of cycles  
        [ Start, Finish ] = locEvents( C )                                  % Return start and finish of discharge events
    end
    
    methods
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
        
        function obj = extractData( obj, FileName )
            %--------------------------------------------------------------
            % Extract data from the datastore & write to the 
            %
            % obj = obj.extractData( FileName );
            %
            % Input Arguments:
            %
            % FileName  --> (string) Name of output file
            %--------------------------------------------------------------
            arguments
                obj
                FileName (1,1) string  { mustBeNonempty( FileName ) }
            end
            %--------------------------------------------------------------
            % Make sure the output file is an xlsx file
            %--------------------------------------------------------------
            FileName = obj.makeExcelFile( FileName );
            obj = obj.resetDs();
            N = obj.NumFiles;
            for Q = 1:N
                %----------------------------------------------------------
                % Fetch the necessary data one file at a time and append to
                % a data table for export
                %----------------------------------------------------------
                SerialNumber = obj.getSerialNumber( Q );
                T = obj.readDs();
                NumCyc = obj.numCycles( T, obj.Current_ );
                [ Start, Finish ] = obj.locEvents( T, obj.Current_ );
                Cycle = ( 1:NumCyc ).';
                DischargeCapacity = T{ Start, obj.Capacity_ } -....
                                    T{ Finish, obj.Capacity_ };
                SerialNumber = repmat( SerialNumber, NumCyc, 1 );
            end
        end % extractData
    end % ordinary methods
    
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
    end % protected static methods
end % rateTestDataImporter