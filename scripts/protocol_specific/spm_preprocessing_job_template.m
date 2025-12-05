% SPM Batch Script for Centiloid Preprocessing (Template)
% This script defines the "Standard PiB Method" pipeline:
% 1. Coregistration (PET -> MRI)
% 2. Unified Segmentation (MRI -> MNI)
% 3. Normalization (Apply deformation to PET)
% 4. Smoothing

% Initialize SPM
spm('defaults', 'FMRI');
spm_jobman('initcfg');

matlabbatch = {};

% === INPUT FILES (Replace these paths for manual use) ===
mri_file = 'path/to/subject_T1w.nii';
pet_file = 'path/to/subject_pet_avg.nii';
% ========================================================

% 1. Coregister: Estimate (Reference: MRI, Source: PET)
matlabbatch{1}.spm.spatial.coreg.estimate.ref = { [mri_file ',1'] };
matlabbatch{1}.spm.spatial.coreg.estimate.source = { [pet_file ',1'] };
matlabbatch{1}.spm.spatial.coreg.estimate.other = {''};
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

% 2. Segment (Unified Segmentation)
% This generates the forward deformation field (y_*.nii)
matlabbatch{2}.spm.spatial.preproc.channel.vols = { [mri_file ',1'] };
matlabbatch{2}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{2}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{2}.spm.spatial.preproc.channel.write = [0 1]; % Save Bias Corrected
matlabbatch{2}.spm.spatial.preproc.tissue(1).tpm = {fullfile(spm('Dir'),'tpm','TPM.nii,1')};
matlabbatch{2}.spm.spatial.preproc.tissue(1).ngaus = 1;
matlabbatch{2}.spm.spatial.preproc.tissue(1).native = [1 0];
matlabbatch{2}.spm.spatial.preproc.tissue(1).warped = [0 0];
matlabbatch{2}.spm.spatial.preproc.tissue(2).tpm = {fullfile(spm('Dir'),'tpm','TPM.nii,2')};
matlabbatch{2}.spm.spatial.preproc.tissue(2).ngaus = 1;
matlabbatch{2}.spm.spatial.preproc.tissue(2).native = [1 0];
matlabbatch{2}.spm.spatial.preproc.tissue(2).warped = [0 0];
matlabbatch{2}.spm.spatial.preproc.tissue(3).tpm = {fullfile(spm('Dir'),'tpm','TPM.nii,3')};
matlabbatch{2}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{2}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{2}.spm.spatial.preproc.tissue(3).warped = [0 0];
matlabbatch{2}.spm.spatial.preproc.tissue(4).tpm = {fullfile(spm('Dir'),'tpm','TPM.nii,4')};
matlabbatch{2}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{2}.spm.spatial.preproc.tissue(4).native = [1 0];
matlabbatch{2}.spm.spatial.preproc.tissue(4).warped = [0 0];
matlabbatch{2}.spm.spatial.preproc.tissue(5).tpm = {fullfile(spm('Dir'),'tpm','TPM.nii,5')};
matlabbatch{2}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{2}.spm.spatial.preproc.tissue(5).native = [1 0];
matlabbatch{2}.spm.spatial.preproc.tissue(5).warped = [0 0];
matlabbatch{2}.spm.spatial.preproc.tissue(6).tpm = {fullfile(spm('Dir'),'tpm','TPM.nii,6')};
matlabbatch{2}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{2}.spm.spatial.preproc.tissue(6).native = [0 0];
matlabbatch{2}.spm.spatial.preproc.tissue(6).warped = [0 0];
matlabbatch{2}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{2}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{2}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{2}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{2}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{2}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{2}.spm.spatial.preproc.warp.write = [1 1]; % Write Deformation Fields

% 3. Normalise: Write (Apply to PET)
matlabbatch{3}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
matlabbatch{3}.spm.spatial.normalise.write.subj.resample = { [pet_file ',1'] };
matlabbatch{3}.spm.spatial.normalise.write.woptions.bb = [-90 -126 -72; 91 91 109];
matlabbatch{3}.spm.spatial.normalise.write.woptions.vox = [2 2 2]; % 2mm isotropic
matlabbatch{3}.spm.spatial.normalise.write.woptions.interp = 4;
matlabbatch{3}.spm.spatial.normalise.write.woptions.prefix = 'w';

% 4. Smooth (8mm FWHM)
matlabbatch{4}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Resampled Images (Subj 1)', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
matlabbatch{4}.spm.spatial.smooth.fwhm = [8 8 8];
matlabbatch{4}.spm.spatial.smooth.dtype = 0;
matlabbatch{4}.spm.spatial.smooth.im = 0;
matlabbatch{4}.spm.spatial.smooth.prefix = 's';

% Run the batch
spm_jobman('run', matlabbatch);
