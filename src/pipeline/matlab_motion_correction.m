% SPM Realignment (Motion Correction) Batch Script
% Parameters:
% inputs{1}: Cell array of input image filenames (the frames to realign)

% Initialise SPM
spm('defaults', 'PET');
spm_jobman('initcfg');

% -----------------------------------------------------------------------
% Job Configuration: Realign: Estimate & Reslice
% -----------------------------------------------------------------------
matlabbatch{1}.spm.spatial.realign.estwrite.data = { inputs{1} };
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = 4;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 1; % Register to mean
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = 2;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = '';

% Reslice Options
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1]; % 2=All Images, 1=Mean Image
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

% Run the job
spm_jobman('run', matlabbatch);
