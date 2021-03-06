classdef (Abstract = true ) pulseTestDataImporter
    % Abstract pulse test data importer class
        
    properties ( SetAccess = protected )
        Ds                                                                  % File data store
        Signals       (1,:)   string                                        % List of available channels
        Data                  table                                         % Data table
        Battery       (1,1)   string          = "LGM50"                     % Battery name
    end % protected properties

    properties ( Abstract = true, SetAccess = protected )
        Current               string                                        % Name of current channel
        Voltage               string                                        % Name of voltage channel
        Capacity              string                                        % Name of capacity channel
        DischgCurrent         double                                        % Discharge current 
        PulseTime             double                                        % Required pulse time [s]
        Time                  string                                        % Name of time channel
        CF                    double                                        % Conversion factor from hours to seconds
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
        Capacity_             string
        Time_                 string
    end    
    
    methods ( Abstract = true )
        obj = extractData( obj, varagin )                                   % Extract data from datastore
        obj = setDischgCurrent( obj, Dc )                                   % Set the discharge current target value
    end % Abstract methods signatures
    
    methods
        function obj = setTime2SecsCF( obj, CF )
            %--------------------------------------------------------------
            % Set the conversion factor for the time channel --> [s]. E.g.
            % if the time channel is in hours, set the CF property to 3600.
            %
            % obj = obj.setTime2SecsCF( CF );
            %
            % Input Arguments:
            %
            % CF    --> (double) conversion factor
            %--------------------------------------------------------------
            arguments
                obj (1,1)
                CF  (1,1) { mustBePositive( CF ), mustBeNonempty( CF ) }
            end
            obj.CF = CF;
        end % setTime2SecsCF
        
        function obj = setPulseTime( obj, T )
            %--------------------------------------------------------------
            % Set the pulse time
            %
            % obj = obj.setPulseTime( T );
            %
            % Input Arguments:
            %
            % T     --> (double) pulse time [s] {10}
            %--------------------------------------------------------------
            arguments
                obj (1,1)
                T   (1,1)   double  { mustBePositive( T ) } = 10;
            end
            obj.PulseTime = T;
        end % setPulseTime
        
        function plotIR( obj )
            %--------------------------------------------------------------
            % Plot the discharge and charge IR data on a two-axis basis
            %
            % obj.plotIR();
            %--------------------------------------------------------------
            figure;
            yyaxis left;
            H = plot( obj.Data.SoC, obj.Data.DischargeIR, 'o');
            H.MarkerEdgeColor = H.Color;
            H.MarkerFaceColor = H.MarkerEdgeColor;
            ylim( [ 0, 0.1 ] );
            xlabel( "SoC [%]" );
            ylabel( "Discharge IR [\Omega]" );
            yyaxis right;
            H = plot( obj.Data.SoC, obj.Data.ChargeIR, 's');
            H.MarkerEdgeColor = H.Color;
            H.MarkerFaceColor = H.MarkerEdgeColor;
            ylim( [ 0, 0.1 ] );
            ylabel( "Charge IR [\Omega]" );
            grid on;
            %--------------------------------------------------------------
            % Turn on the grid
            %--------------------------------------------------------------
            Ax = gca;
            Ax.GridAlpha = 0.75;
            Ax.GridColor = [0.025 0.025 0.025];
            Ax.GridLineStyle = "--";
            title( string( obj.Facility ), 'FontSize', 18 );
        end % plot
        
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
    
    methods ( Access = protected )
    end % protected methods
    
    methods
        function N = get.NumFiles( obj )
            % Return number of files in datastore
            N = numel( obj.Ds.Files );
        end        
        
        function C = get.Capacity_( obj )
            % Return parsed capacity channel
            C = obj.parseChannelName( obj.Capacity );
        end
        
        function C = get.Current_( obj )
            % Return parsed current channel
            C = obj.parseChannelName( obj.Current );
        end       
        
        function C = get.Voltage_( obj )
            % Return parsed current channel
            C = obj.parseChannelName( obj.Voltage );
        end
        
        function C = get.Time_( obj )
            % Return parsed current channel
            C = obj.parseChannelName( obj.Time );
        end
    end % GET/SET Methods
    
    methods ( Access = protected )
        function [ D_IR, C_IR, D_DV, D_DI, C_DV, C_DI ] = calcIR( obj, T, Start, Finish )
            %--------------------------------------------------------------
            % Calculate the discharge and charge internal resistance values
            %
            % [ D_IR, C_IR ] = obj.calcIR( T, Start, Finish );
            %
            % T         --> (table) data table
            % Start     --> (double) start of discharge events
            % Finish    --> (double) finish of discharge events
            %
            % Output Arguments
            %
            % D_IR  --> Discharge internal resitance values (Ohms)
            % C_IR  --> Charge internal resitance values (Ohms)
            % D_DV  --> Discharge pulse delta voltage
            % D_DI  --> Discharge pulse delta current
            % C_DV  --> Charge pulse delta voltage
            % C_DI  --> Charge pulse delta current
            %--------------------------------------------------------------
            N = numel( Start );
            [ D_DV, D_DI, C_DV, C_DI ] = deal( zeros( N, 1 ) );
            %--------------------------------------------------------------
            % Define voltage and current channel names in the data table
            %--------------------------------------------------------------
            Vname = obj.Voltage_;
            Iname = obj.Current_;
            Tname = obj.Time_;
            I = T.( Iname );
            V = T.( Vname );
            Tm = T.( Tname );
            BI = max( abs( [ min( I ), max( I ) ] ) );
            AI = - BI;
            BV = max( abs( [ min( V ), max( V ) ] ) );
            AV = -BV;
            Ic = obj.codeData( I, AI, BI );
            Vc = obj.codeData( V, AV, BV );
            D_Ok = false( N, 1 );
            C_Ok = D_Ok;
            for Q=1:N
                %----------------------------------------------------------
                % Calculate the internal resistance values
                %----------------------------------------------------------
                if ( Q < N )
                    Tidx = Finish( Q ):Start( Q + 1 );
                else
                    Tidx = Finish( Q ):numel( Vc );
                end
                I = Ic( Tidx );
                V = Vc( Tidx );
                %----------------------------------------------------------
                % Find the discharge & charge pulse event locations
                %----------------------------------------------------------
                [ Dstart, Dfinish ] = obj.locateDischgPulse( I );
                [ ~, D_Ok( Q ) ] = obj.getPulseWidth( Tm( Tidx ), Dstart, Dfinish );
                [ Cstart, Cfinish ] = obj.locateChgPulse( I );
                [ ~, C_Ok( Q ) ] = obj.getPulseWidth( Tm( Tidx ), Cstart, Cfinish );
                %----------------------------------------------------------
                % Discharge value
                %----------------------------------------------------------
                D_DV( Q ) = abs( ( V( Dstart ) - V( Dfinish ) ) );
                D_DI( Q ) = median( I( Dstart:Dfinish ) );
                %----------------------------------------------------------
                % Charge value
                %----------------------------------------------------------
                C_DV( Q ) = abs( ( V( Cfinish ) - V( Cstart ) ) );
                C_DI( Q ) = median( I( Cstart:Cfinish ) );
            end
            D_DV = obj.decodeData( D_DV, AV, BV );
            D_DI = abs( obj.decodeData( D_DI, AI, BI ) );
            D_IR =  D_DV ./ D_DI;
            D_IR( ~D_Ok ) = NaN;
            C_DV = obj.decodeData( C_DV, AV, BV );
            C_DI = abs( obj.decodeData( C_DI, AI, BI ) );
            C_IR =  C_DV ./ C_DI;    
            C_IR( ~C_Ok ) = NaN;
        end % calcIR
        
        function [ SoC, MaxCap ] = calcSoC( obj, T, Start, Finish )
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
            %
            % Output Arguments:
            %
            % SoC       --> (double) State of charge vector
            % MaxCap    --> (double) Maximum observed capacity of the cell
            %--------------------------------------------------------------
            N = numel( Start );                                             % Number of cycles
            C = T.( obj.Capacity_ );                                        % Capacity data
            MaxCap = max( C );                                              % Maximum capacity
            SoC = zeros( N, 1 );                                            % Define storage
            for Q = 1:N
                %----------------------------------------------------------
                % Calculate the SoC
                %----------------------------------------------------------
                S = max( C( ( Start( Q ) ):Finish( Q ) ) );
                SoC( Q ) = S / MaxCap;
            end
        end % calcSoC
        
        function [ Start, Finish ] = locEvents( obj, T, EventChannel, Thresh )
            %--------------------------------------------------------------
            % Locate start and finish of discharge events
            %
            % [ Start, Finish ] = obj.locEvents( T, EventChannel, Thresh );
            %
            % Input Arguments:
            %
            % T             --> (table) data table
            % EventChannel  --> (string) Name of channel defining event
            % Thresh        --> (double) test threshold for detecting the
            %                            charge pulse { 0.05 } [A].
            %--------------------------------------------------------------
            if ( nargin < 4 ) || isempty( Thresh )
                Thresh = 0.005;
            else
                Thresh = double( Thresh );
            end
            %--------------------------------------------------------------
            % Code the data onto the interval [ -1, 1 ]
            %--------------------------------------------------------------
            C = ( T.( EventChannel ) );
            B = max( abs( [ max( C ), min( C ) ] ) );
            A = -B;
            Xc = obj.codeData( C, A, B );
            Tgt = obj.codeData( obj.DischgCurrent, A, B );
            Idx = ( abs( Xc - Tgt ) < Thresh );                             % locate the discharge pulses
            C( ~Idx ) = 0; 
            %--------------------------------------------------------------
            % Locate the start and finish of the discharge pulses
            %--------------------------------------------------------------
            S = sign( C );
            S( S > 0 ) = 0;
            S = diff( S );
            Start = find( S < 0, numel( S ), 'first' );
            Start = Start + 1;
            Finish = find( S > 0, numel( S ), 'first' );
            Finish = Finish + 1;
        end % locEvents
    end % protected methods
    
    methods ( Static = true, Access = protected )
        function [ Xc, A, B ] = codeData( X, A, B )
            %--------------------------------------------------------------
            % Code the supplied data onto the interval [ -1, 1 ]
            %
            % Xc = obj.codeData( X, A, B );
            %
            % Input Arguments:
            %
            % X     --> (double) data in engineering units
            % A     --> (double) minimum value in natural scale A --> -1
            % B     --> (double) maximum value in natural scale B --> +1
            %
            % Output Arguments:
            % Xc    --> (double) coded data
            % A     --> (double) minimum supplied data value
            % B     --> (double) maximum supplied data value
            %--------------------------------------------------------------
            if ( nargin < 2 ) || isempty( A )
                A = min( X );
            end
            if ( nargin < 3 ) || isempty( B )
                B = max( X );
            end
            C = mean( [ A, B ] );
            Xc = 2 * ( X - C ) / ( B - A );
        end % codeData
        
        function X = decodeData( Xc, A, B )
            %--------------------------------------------------------------
            % Code the supplied data onto the interval [ -1, 1 ]
            %
            % X = obj.decodeData( Xc, A, B );
            %
            % Input Arguments:
            %
            % Xc    --> (double) data in coded units
            % A     --> (double) minimum value in natural scale A --> -1
            % B     --> (double) maximum value in natural scale B --> +1
            %
            % Output Arguments:
            % X     --> (double) data in natural units
            % A     --> (double) minimum supplied data value
            % B     --> (double) maximum supplied data value
            %--------------------------------------------------------------
            C = mean( [ A, B ] );
            X = 0.5 * ( B - A ) * Xc + C;
        end % decodeData        
        
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
        
        function [ Start, Finish ] = locateDischgPulse( I )
            %--------------------------------------------------------------
            % Locate the short discharge pulse event locations
            %
            % [ Start, Finish ] = obj.locateDischgPulse( I );
            %
            % Input Arguments:
            %
            % I     --> Current trace
            %
            % Output Arguments:
            % 
            % Start     --> Starting index for discharge pulse
            % Finish    --> Finishing index for discharge pulse
            %--------------------------------------------------------------
            I( I > 0 ) = 0;
            S = sign( I );
            S = diff( S );
            Start = find( S < 0, 1, 'first' );
            Start = Start + 1;
            Finish = find( S > 0, 1, 'first' );
            Finish = Finish + 1;
        end % locateDischgPulse
        
        function [ Start, Finish ] = locateChgPulse( I )
            %--------------------------------------------------------------
            % Locate the short charge pulse event locations
            %
            % [ Start, Finish ] = obj.locateChgPulse( I );
            %
            % Input Arguments:
            %
            % I     --> Current trace
            %
            % Output Arguments:
            % 
            % Start     --> Starting index for charge pulse
            % Finish    --> Finishing index for charge pulse
            %--------------------------------------------------------------
            I( I < 0 ) = 0;
            I = diff( I );
            Start = find( I > 0, 1, 'first' );
            Start = Start + 1;
            Finish = find( I < 0, 1, 'last' );
            Finish = Finish + 1;
        end % locateChgPulse  
        
        function Ir = iRisNanOrZero( Ir )
            %--------------------------------------------------------------
            % If IR id infinity or less than or equal to zero replace with 
            % NaN
            %
            % Ir = obj.iRisNanOrZero( Ir )
            %
            % Input Arguments:
            %
            % Ir    --> (double) Internal resitance vector
            %--------------------------------------------------------------
            Ir( isinf( Ir ) ) = NaN;
            Ir( ( Ir <= 0 ) ) = NaN;
        end % iRisNanOrZero
    end % protected static methods
    
    methods ( Access = private )
        function  [ Dt, Ok ] = getPulseWidth( obj, Tm, Start, Finish)
            %--------------------------------------------------------------
            % Calculate the width of the pulse
            %
            % Dt = obj.getPulseWidth( Tm, Start, Finish);
            %
            % Input Arguments:
            %
            % Tm        --> Time vector [s]
            % Start     --> Starting index for pulse
            % Finish    --> Finishing index for pulse
            %
            % Output Arguments:
            %
            % Dt        --> Width of applied pulse [s]
            % Ok        --> (logical) true if Dt >= obj.PulseTime
            %--------------------------------------------------------------
            Dt = Tm( Start:Finish );
            Dt = round( obj.CF * ( max( Dt ) - min( Dt ) ) );
            Ok = ( Dt >= obj.PulseTime );
        end % getPulseWidth
    end % private methods
end % pulseTestDataImporter