function [net, info] = train_cnn_dcf(varargin)
%CNN_DCF
run('vl_setupnn.m') ;

opts.network = [] ;
opts.networkType = 'dagnn' ;
opts.expDir = fullfile('../data', 'vot-vgg-dcf') ;
opts.dataDir = fullfile('../data', 'vot16') ;
opts.imdbPath = fullfile(opts.expDir, 'imdb.mat');


if ispc()
    trainOpts.gpus = [1];
else
    trainOpts.gpus = [];
end
trainOpts.learningRate = 1e-3;
trainOpts.weightDecay = 0.0005;
trainOpts.numEpochs = 50;
trainOpts.batchSize = 1;
opts.train = trainOpts;

if ~isfield(opts.train, 'gpus'), opts.train.gpus = []; end;

% --------------------------------------------------------------------
%                                                         Prepare data
% --------------------------------------------------------------------

if isempty(opts.network)
  net = cnn_dcf_init() ;
else
  net = opts.network ;
  opts.network = [] ;
end

if exist(opts.imdbPath, 'file')
  imdb = load(opts.imdbPath) ;
else
  imdb = getVOTImdb(opts) ;
  mkdir(opts.expDir) ;
  save(opts.imdbPath, '-v7.3', '-struct', 'imdb') ;
end

% --------------------------------------------------------------------
%                                                                Train
% --------------------------------------------------------------------

switch opts.networkType
  case 'simplenn', trainfn = @cnn_train ;
  case 'dagnn', trainfn = @cnn_train_dag ;
end

[net, info] = trainfn(net, imdb, getBatch(opts), ...
  'expDir', opts.expDir, ...
  opts.train, ...
  'val', imdb.images.set == 3) ;
end

% --------------------------------------------------------------------
function fn = getBatch(opts)
% --------------------------------------------------------------------
bopts = struct('numGpus', numel(opts.train.gpus),'sz', [227,227]) ;
fn = @(x,y) getDagNNBatch(bopts,x,y) ;
end

% --------------------------------------------------------------------
function inputs = getDagNNBatch(opts, imdb, batch)
% --------------------------------------------------------------------

if opts.numGpus > 0
    target = gpuArray(bsxfun(@minus,single(imdb.images.target(:,:,:,batch)),imdb.images.data_mean));
    search = gpuArray(bsxfun(@minus,single(imdb.images.search(:,:,:,batch)),imdb.images.data_mean));
    delta_yx = gpuArray(single(imdb.images.delta_yx(batch,1:2)));
else
    target = bsxfun(@minus,single(imdb.images.target(:,:,:,batch)),imdb.images.data_mean);
    search = bsxfun(@minus,single(imdb.images.search(:,:,:,batch)),imdb.images.data_mean);
    delta_yx = single(imdb.images.delta_yx(batch,1:2));
end

inputs = {'target', target, 'search', search,'delta_yx',delta_yx} ;
end