classdef lancasterRateTestData < rateTestDataImporter
    % Concrete rate test data interface for facility correlation analysis
    % for Lancaster BATLAB data
    
    properties ( Constant = true )
        Fileformat (1,1)      string                = "csv"                 % Supported input formats
    end % abstract & constant properties
        
    methods
        function obj = lancasterRateTestData( RootDir, NumHeaderLines )
            %--------------------------------------------------------------
            % lancasterRateTestData constructor. Imports correlation rate
            % test data and converts it to standard format
            %
            % obj = lancasterRateTestData( RootDir, NumHeaderLines );
            %
            % Input Arguments:
            %
            % RootDir           --> Root directory where data is held. User 
            %                       is prompted for the directory if empty
            % NumHeaderLines    --> Number of header lines in file
            %--------------------------------------------------------------
            if ( nargin < 1 )
                RootDir = uigetdir( cd, "Select root directory containing Lancaster rate test data" );
            elseif ~isfolder( RootDir )
                error( '"%s" is not a valid folder', RootDir );
            end
            RootDir = string( RootDir );
            %--------------------------------------------------------------
            % Create data store
            %--------------------------------------------------------------
            obj.Ds = tabularTextDatastore( RootDir, 'FileExtensions', ...
                        obj.Fileformat, 'IncludeSubfolders', true, ...
                        'OutputType', "table", 'TextType', "string" );
            obj.NumHeaderLines
        end
    end % constructor and ordinary methods
end % lancasterRateTestData