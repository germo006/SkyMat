% Noah Germolus 06 May 2021
% This script is designed to be a wrapper for considerSkyline.m, and both
% are based on the considerMAVEN/riMAVEN code by Krista Longnecker. 
% The objective of these combined files is to take output from Skyline
% (peak areas from UPLC-Orbitrap data) and convert it to concentrations by
% using a standard curve as a ratio (light/heavy).

%
% Yuting Zhu start editing the script 3/23/23

clear

%% Set filenames
fileBase = 'testing_Compilation_3isotopes'; % Set this, don't mess with the automatic date system.
today = datestr(datetime('now'),'.yyyy.mm.dd');
NameOfFile = string([fileBase,today,'_C13.mat']);

%% Set the sequence file here.
wDir = '/Volumes/KujLab/Brianna/Projects/Skyline_MATLAB_codeCompilation/testing/3_isotopes_Skyline/raw_file_example';
fName = 'CMP_Yuting_Exomtab_pos_redo_022323.xlsx';
sampleInfoFile = string([wDir filesep fName]);

clear wDir

%% Set the location and names of the quantification tables exported from Skyline
sDir = '/Volumes/KujLab/Brianna/Projects/Skyline_MATLAB_codeCompilation/testing/3_isotopes_Skyline/Skyline';
dfile_pos = string([sDir filesep 'Skyline_pos_test_3isotopes_QuantTable_manipulated.csv']);
dfile_neg = string([sDir filesep 'CINAR_quant_neg.csv']); 
clear sDir

%% Set directory for where SkyMat codes are - this will create an output folder for your results
oDir = '/Volumes/whoi/dept/mcg/KujLab/Brianna/Projects/Skyline_MATLAB_codeCompilation/testing/3_isotopes_Skyline/SkyMat';
oFolder = string([oDir filesep 'Output']);
mkdir(oFolder);

cd(oFolder);

clear oDir 

%% ConsiderSkyline processing for positive mode.

units = 'ng'; %set unit for standard curve (e.g., ng or pg)

[pos_C13.sNames, pos_C13.kgd] = considerSkyline(dfile_pos, sampleInfoFile,...
    'pos','heavyC13',2, units, oFolder);

%% ConsiderSkyline processing for negative mode.

[neg_C13.sNames, neg_C13.kgd] = considerSkyline(dfile_neg, sampleInfoFile,...
 'neg','heavyC13',2, units, oFolder);

%% Save temporary file before merging data 

save('temp_C13');

%% MERGING DATA FROM TWO MODES
clear fName fileBase today

% The traditional approach here is to take both metabolite lists, positive
% and negative mode, and keep both sets of data and append the ion mode to
% the metabolite name. In the future, there may be a different routine that
% automatically calibrates each metabolite at each sample using both the
% mode and isotope that give the tightest error bounds, eliminating this
% step. 
mtabNames_C13 = sort(cat(1,[neg_C13.kgd.names + " neg"],[pos_C13.kgd.names + " pos"]));
if length(unique(mtabNames_C13)) ~= length(mtabNames_C13)
    error('Something is wrong - duplicate names in the list of metabolites')
end

% For the pooled samples (and perhapds others), I will have duplicate sets 
% of names with either _pos or _neg appended; 
tInfo_C13 = readtable(sampleInfoFile);
clear sampleInfoFile

% Before I dive into the unknowns, remove anything that has goodData = 0
% This step does take place within considerSkyline, but we're re-reading
% the sample info file here to create permanent variables for the
% workspace, which need to be re-pruned.
k = find(tInfo_C13.goodData==0);
tInfo_C13(k,:) = [];
clear k

% First, go through and iterate through the pooled samples
% to provide numbers for these (otherwise will have duplicate
% names). Need to do separately for both modes.
s = contains(tInfo_C13.SampleName,'pool') & contains(tInfo_C13.SampleName,'pos');
ks = find(s==1);
for a = 1:length(ks)
    t = tInfo_C13.SampleName(ks(a));
    tInfo_C13.SampleName(ks(a)) = strcat('pool',num2str(a,'%02.f'),'_',t); %YZ 03.31.2023 added '%02.f'
    clear t
end
clear a ks a

s = contains(tInfo_C13.SampleName,'pool') & contains(tInfo_C13.SampleName,'neg');
ks = find(s==1);
for a = 1:length(ks)
    t = tInfo_C13.SampleName(ks(a));
    tInfo_C13.SampleName(ks(a)) = strcat('pool',num2str(a,'%02.f'),'_',t); %YZ 03.31.2023 added '%02.f'
    clear t
end
clear a ks a

% Now find the Unknown...should have the same number for positive and
% negative ion mode.
s = strcmp(tInfo_C13.SampleType,'Unknown');
sp = strcmp(tInfo_C13.ionMode,'pos');
ksp = (find(s==1 & sp==1));
sn = strcmp(tInfo_C13.ionMode,'neg');
ksn = (find(s==1 & sn==1));

if ~isequal(length(ksp),length(ksn))
    error('Something wrong, these should be the same length')
end
clear s sp sn ksp ksn

% Parse out the names. Use this to figure out the unique samples and setup
% a new matrix that I can propagate with the metabolites from both positive
% and negative ion mode. Bit of a hack, and growing worse.
% NPG 20 Sept 2023: I think this whole section might need to be removed.
% We're adding extra columns for parsing out sample metadata, which is
% something I do in downstream processing or have straight-up in the sample
% info table. It doesn't really do much good to have this "hack" present in
% what's supposed to be the basic processing script. 
nrow = size(tInfo_C13,1);
tInfo_C13.type = repmat({''},nrow,1);
tInfo_C13.cName = repmat({''},nrow,1);
% examples of additional columns used in the BIOS-SCOPE project
% tInfo_C13.cruise = repmat({''},nrow,1);
% tInfo_C13.cast = zeros(nrow,1);
% tInfo_C13.niskin = zeros(nrow,1);
% tInfo_C13.depth = zeros(nrow,1);
% tInfo_C13.addedInfo = repmat({'none'},nrow,1);

for a = 1:nrow
    if strcmp(tInfo_C13.SampleType{a},'Unknown') %only do unknowns      
        one = tInfo_C13.SampleName{a};
        r_pooled = regexp(one,'pool');
            if r_pooled
                %pooled sample
                tInfo_C13.type(a) = {'pooled'};
                %put the number of this pooled sample into 'addedInfo'
                r_nL = regexp(one,'p'); %lower case
                r_nU = regexp(one,'C'); %upper case
                %tInfo_C13.addedInfo(a) = {one(r_nL+1 : r_nU-1)};
                tInfo_C13.addedInfo(a) = {'pooled'};
                tInfo_C13.cName(a) = {one(1:r_nU-1)};
            else
                %actual sample
                tInfo_C13.addedInfo(a) = {'sample'}; %redundant...
                tInfo_C13.cName(a) = {one(1:end-4)};
                %fprintf('here')
            end
        clear one r_* under
    end
end
clear a nrow

% NPG 20 Sept 2023: This used to take five lines. Not sure why. But, this
% makes a table with the sample names as the first column. 
sInfo_C13 = table(unique(tInfo_C13.cName), 'VariableNames','cName');

% Preallocate double-type matrix for metabolite data.
mtabData_C13 = zeros(size(mtabNames_C13,1),size(sInfo_C13,1));
mtabData_C13_filtered = zeros(size(mtabNames_C13,1),size(sInfo_C13,1));

% Need to track some additional details; namely which file came from which
% ion mode.
mtabDetails_C13 = table();

% Get the index for rows for positive AND negative mtabs and reorder. 
kgdNames = [pos_C13.kgd.names + " pos";neg_C13.kgd.names + " neg"]; 
[c idx_New idx_Old] = intersect(mtabNames_C13,kgdNames);
all_LOD = [pos_C13.kgd.LOD;neg_C13.kgd.LOD]; 
LOD_C13 = all_LOD(idx_Old);
all_LOQ = [pos_C13.kgd.LOQ;neg_C13.kgd.LOQ]; 
LOQ_C13 = all_LOQ(idx_Old);


clear c idx_New idx_Old all_LOD kgdNames all_LOQ

[c idx_posNew idx_posOld] = intersect(mtabNames_C13,pos_C13.kgd.names + " pos");
[c idx_negNew idx_negOld] = intersect(mtabNames_C13,neg_C13.kgd.names + " neg");


mtabDetails_C13.mode(idx_posNew,1) = {'pos'};
mtabDetails_C13.mode(idx_negNew,1) = {'neg'};

sInfo_C13.runOrder_pos(:,1) = 0;
sInfo_C13.runOrder_neg(:,1) = 0;

sInfo_C13.FileName_pos(:,1) = {''};
sInfo_C13.FileName_neg(:,1) = {''};

% This section takes the ordered sample names and metabolite names and
% reshuffles the mode-specific calibrated measurements into a single
% matrix. It also contains some of the metadata hack from earlier that
% should be removed (commented lines).
for a = 1:size(sInfo_C13,1)
    s = strcmp(sInfo_C13.cName(a),tInfo_C13.cName);
    ks = find(s==1);
    % The section starts by searching a sample name, anticipating both a
    % pos and neg mode for each sample. 
    if length(ks) ~= 2
        error('Something is wrong, should be two of each')
        % If you get this error, check to see if your goodData column is
        % properly pruning your data so that there's the same number of
        % files for each mode, AND that all your cNames are actually the
        % same across modes--typos happen. 
    end
    
    for aa = 1:2
        %propagate sInfo_C13 with the cast/depth/etc. information, only do once
%         if aa == 1
%             sInfo_C13.type(a) = tInfo_C13.type(ks(aa));
%             sInfo_C13.cName(a) = tInfo_C13.cName(ks(aa));
%             sInfo_C13.cruise(a) = tInfo_C13.cruise(ks(aa));
%             sInfo_C13.cast(a) = tInfo_C13.cast(ks(aa));
%             sInfo_C13.niskin(a) = tInfo_C13.niskin(ks(aa));
%             sInfo_C13.depth(a) = tInfo_C13.depth(ks(aa));
%             sInfo_C13.addedInfo(a) = tInfo_C13.addedInfo(ks(aa));
%         end
        % Two cases, because depending on the ionMode, we're shifting data
        % from a different struct into the data matrices.
        im = tInfo_C13.ionMode{ks(aa)};
        if isequal(im,'pos')
            tName = tInfo_C13.FileName(ks(aa));
            sInfo_C13.FileName_pos(a,1) = tName;

            [c ia tIdx] =intersect(tName,pos_C13.sNames);
            mtabData_C13(idx_posNew,a) = pos_C13.kgd.goodData(idx_posOld,tIdx);
            mtabData_C13_filtered(idx_posNew,a) = pos_C13.kgd.goodData_filtered(idx_posOld,tIdx);
            clear c ia tIdx tName
            
        elseif isequal(im,'neg')
            tName = tInfo_C13.FileName(ks(aa));
            sInfo_C13.FileName_neg(a,1) = tName;

            [c ia tIdx] =intersect(tName,neg_C13.sNames);
            mtabData_C13(idx_negNew,a) = neg_C13.kgd.goodData(idx_negOld,tIdx);
            mtabData_C13_filtered(idx_negNew,a) = neg_C13.kgd.goodData_filtered(idx_negOld,tIdx);
            clear c ia tIdx tName
        else 
            error('Something wrong')
        end
        clear im
    end
    clear aa s ks        
end
clear a

clear idx_*

clear r s

% Sort the actual datafile names into their respective ion mode columns. 
for a = 1: size(sInfo_C13,1)
    %do positive ion mode first
    gc = sInfo_C13{a,'FileName_pos'}{:}; %added {:} to deal with table output
    t = regexp(gc,'_');
    if ~isempty(t)
        sInfo_C13.runOrder_pos(a,1) = str2num(gc(t(end)+1:end));
    else
        sInfo_C13.runOrder_pos(a,1) = NaN;
    end
    clear gc t
    
    %then negative ion mode
    gc = sInfo_C13{a,'FileName_neg'}{:}; %added {:} to deal with table output
    t = regexp(gc,'_');
    if ~isempty(t)
        sInfo_C13.runOrder_neg(a,1) = str2num(gc(t(end)+1:end));
    else
        sInfo_C13.runOrder_neg(a,1) = NaN;
    end
    clear gc t
end
clear a
 
clear a dfile_neg dfile_pos neg_info pos_info sampleInfoFile_neg ...
    sampleInfoFile_pos
 
save(NameOfFile)

%% Use the convertMoles.m function to convert from mass to concentration 
%(e.g., pg to pM)
% input variables for function include:
% tDir - directory where your transition list is found that includes
% columns for isPrecursor and StdMW
%tFile - the name of the Transition list file in .csv format.
%mtabNames - this can be either _C13, _D5, or the _filtered version of
%those
%units - should be defined earlier as 'pg' or 'ng'
%volume in mL - for example here '25' as a numeric input

tDir = 'InsertHere';
tFile = string([tDir filesep 'InsertHere']);

mtabData_conc = convertMoles(tFile, mtabNames_C13, mtabData_C13, units, 25);

save(NameOfFile)
