classdef warwickRateTestData < rateTestDataImporter
    % Concrete rate test data interface for facility correlation analysis
    % for Warwick data    
    
    properties ( Constant = true )
        Fileformat            string                = ".mat"                % Supported input formats
        Tester                string                = "Novonix"             % Type of battery tester
        Facility              correlationFacility   = "Warwick"             % Facility name
    end % abstract & constant properties   
    
end % warwickRateTestData