function [modality,betak,Rml,muml,wml,tl,Fl,Z_res] = jh_fit_exp_file(filename,fun,varargin)
%JH_FIT_EXP_FILE Fit an experimental data file with the specified impedance model.
%   Detailed explanation goes here

    parser = inputParser();
    addOptional(parser,'plot',true)
    parse(parser,varargin{:})
    
    % load data
    data_path = '../../../data/experimental';
    if strcmp(filename,'DRTtools_LIB_data.txt')
        data = readtable(strcat(data_path,'/',filename),'Delimiter','\t');
        data.Properties.VariableNames{'Var1'} = 'Freq';
        data.Properties.VariableNames{'Var2'} = 'Zreal';
        data.Properties.VariableNames{'Var3'} = 'Zimag';
    elseif strcmp(filename,'PDAC_COM3_02109_Contact10_2065C_500C.txt')
        data = readtable(strcat(data_path,'/',filename),'HeaderLines',22);
        data.Properties.VariableNames{'Var4'} = 'Freq';
        data.Properties.VariableNames{'Var5'} = 'Zreal';
        data.Properties.VariableNames{'Var6'} = 'Zimag';
    else
        data = readtable(strcat(data_path,'/',filename));
    end
    
    data.w = data.Freq*2*pi;
    mdata = table2array(data(:,{'w' 'Zreal' 'Zimag'}));
    
    functionHandle=functions(fun);
    
    % set initial estimates
    if strcmp(filename(1:17),'DRTtools_LIB_data')
        if strcmp(functionHandle.function,'DRT')
            distType={'series'};
            Rinf = 0.11;
            betak = Rinf;
            Rtaul=[0.08,1e2];
            mue = -7;
        elseif strcmp(functionHandle.function,'jh_DRT_WithInductance')
            distType={'series'};
            Rinf = 0.11;
            induc = 1e-6;
            betak = [Rinf; induc];
            Rtaul=[0.08,1e2];
            mue = -7;
        end
    elseif strcmp(filename,'PDAC_COM3_02109_Contact10_2065C_500C.txt')
        if strcmp(functionHandle.function,'DRT')
            distType={'series'};
            Rinf = 4e3;
            betak = Rinf;
            Rtaul=[18e6,1];
            mue = -7;
       elseif strcmp(functionHandle.function,'jh_DRT_TpDDT') ||  strcmp(functionHandle.function,'jh_DRT_TpGer')
            distType = {'series' 'parallel'}; 
            Rinf=4e3; R1=5e6; R2=13e6;
            tau1 = 1e-3;
            tau2 = 1;
            betak=Rinf;
            Rtaul=[R1,tau1; R2, tau2];
            mue=-7;
        end
    end   

    start = datetime;
    [modality,betak,Rml,muml,wml,...
    betakn,Rmln,mumln,wmln,...
    wen,...
    tl,Fl]=invertEIS(fun,mdata,distType,betak,Rtaul,mue);
    fin = datetime;
    disp(['Run time: ',num2str(minutes(fin-start)),' minutes'])

    % get impedance fit
    Zhat_full = exactModel(fun,betak,Rml(:,2),muml(:,2),wml(:,2),modality,distType);
    Zhat_size = size(Zhat_full);
    % for DRT_WithInductance, Zhat_full is Nx1. not sure why
    if Zhat_size(2)==1
        Zhat = Zhat_full;
    else
        Zhat = Zhat_full(:,2);
    end
    Z_res = array2table([data.Freq real(Zhat) imag(Zhat)],...
    'VariableNames',{'freq' 'Zreal' 'Zimag'});

    % show plot if requested
    if parser.Results.plot

        %% 1st dist plot
        figure()
         
        % plot point estimate and CI
        FlTemp=Fl{1};
        plot(tl{1},FlTemp(2,:),'r','LineWidth',1,'DisplayName','Inversion Output')
        hold('on')
        plot(tl{1},FlTemp(1,:),'r-.','LineWidth',1,'HandleVisibility','off')
        plot(tl{1},FlTemp(3,:),'r-.','LineWidth',1,'HandleVisibility','off')
        
        % Labels
        xlabel('t')
        ylabel('F_1(t)')
        legend()
        
        % title
        suptitle(strcat(filename,' DRT'))
        
        %% TP-DDT plot
        if strcmp(functionHandle.function,'jh_DRT_TpDDT') || strcmp(functionHandle.function,'jh_DRT_TpDDT_BpDDT') || strcmp(functionHandle.function,'jh_DRT_TpGer')
            figure()

            % plot point estimate and CI
            FlTemp=Fl{2};
            plot(tl{2},FlTemp(2,:),'r','LineWidth',1,'DisplayName','Inversion Output')
            hold('on')
            plot(tl{2},FlTemp(1,:),'r-.','LineWidth',1,'HandleVisibility','off')
            plot(tl{2},FlTemp(3,:),'r-.','LineWidth',1,'HandleVisibility','off')

            % Labels
            xlabel('t')
            ylabel('F_1(t)')
            legend()

            % title
            suptitle(strcat(filename,' TP-DDT'))
        end
        
        %% BP-DDT plot
        if strcmp(functionHandle.function,'jh_DRT_TpDDT_BpDDT')
            figure()

            % plot point estimate and CI
            FlTemp=Fl{3};
            plot(tl{3},FlTemp(2,:),'r','LineWidth',1,'DisplayName','Inversion Output')
            hold('on')
            plot(tl{3},FlTemp(1,:),'r-.','LineWidth',1,'HandleVisibility','off')
            plot(tl{3},FlTemp(3,:),'r-.','LineWidth',1,'HandleVisibility','off')

            % Labels
            xlabel('t')
            ylabel('F_1(t)')
            legend()

            % title
            suptitle(strcat(filename,' BP-DDT'))
        end
        
        %% Bode plot
        figure()
        axr = subplot(1,2,1);
        axi = subplot(1,2,2);
        
        % plot point estimate only
%         Zhat = Zhat_full(:,2);
%         Zhat_lo = Zhat_full(:,1);
%         Zhat_hi = Zhat_full(:,3);
        
        % plot real impedance
        plot(axr,log10(data.Freq),real(Zhat),'r','DisplayName','Fit')
        hold(axr,'on')
%         plot(axr,log10(data.Freq),real(Zhat_lo),'r-.','DisplayName','')
%         plot(axr,log10(data.Freq),real(Zhat_hi),'r-.','DisplayName','')
        scatter(axr,log10(data.Freq),data.Zreal,10,'k',...
            'DisplayName','Data')
        xlabel(axr,'log(f)')
        ylabel(axr,"Z'")
        legend(axr)
        
        % plot imag impedance
        plot(axi,log10(data.Freq),imag(Zhat),'r','DisplayName','Fit')
        hold(axi,'on')
%         plot(axi,log10(data.Freq),imag(Zhat_lo),'r','DisplayName','')
%         plot(axi,log10(data.Freq),imag(Zhat_hi),'r','DisplayName','')
        scatter(axi,log10(data.Freq),data.Zimag,10,'k',...
            'DisplayName','Data')
        xlabel(axi,'log(f)')
        ylabel(axi,"Z''")
        legend(axi)
        
        % title
        suptitle(strcat(filename,' ',functionHandle.function))
        
        
    end
    
end

