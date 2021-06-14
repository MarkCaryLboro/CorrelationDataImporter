classdef ( Abstract = true ) rateTestDataImporter
    % Abstract rate test data interface class
    
    properties ( SetAccess = protected )
        Ds                                                                  % File data store
    end % protected properties
    
    properties ( Constant = true, Abstract = true )
        Fileformat (1,1)      string                                        % Supported input formats
        Tester     (1,1)      string                                        % Type of battery tester
    end % abstract & constant properties
    
    methods ( Abstract = true )
        
    end % Abstract methods signatures
    
    methods
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
        
        function obj = resetDS( obj )
            %--------------------------------------------------------------
            % Reset the datastore to the unread state
            %
            % obj = obj.resetDS();
            %--------------------------------------------------------------
            reset( obj.Ds );
        end % resetDS
    end % ordinary methods
    
    methods
    end % get/set methods
    
    methods ( Access = protected )
    end % protected methods    
    
    
end % rateTestDataImporter