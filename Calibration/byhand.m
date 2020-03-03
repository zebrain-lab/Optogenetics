
t1 = imregtform(twop,cam,'affine',optimizer,metric);
t2 = imregtform(cam,twop,'affine',optimizer,metric);

% doesn't work ?
[optimizer, metric] = imregconfig('multimodal');
optimizer.MaximumIterations = 1000;
tform = imregtform(moving, fixed, 'affine', optimizer, metric)

movingRegistered = imwarp(moving,tform,'OutputView',imref2d(size(fixed)));
figure
imshowpair(fixed, movingRegistered,'Scaling','joint')


% cpselect
cd('E:\Martin\Optogenetics\Calibration')
files = {'twop10.jpg',...
        'twop11.jpg',...
        'twop12.jpg',...
        'twop13.jpg',...
        'twop14.jpg',...
        'twop15.jpg',...
        'twop16.jpg',...
        'twop17.jpg',...
        'twop18.jpg',...
        'twop19.jpg',...
        'twop20.jpg',...
        'twop25.jpg',...
        'twop30.jpg',...
        'twop35.jpg',...
        'twop40.jpg'};

Tforward = [];
Treverse = [];
fixed = imread('cam.jpg');
for i=6:numel(files)
    moving = imread(files{i});
    [movingPoints fixedPoints] = cpselect(moving,fixed,'Wait',true);
    movingPoints = [movingPoints ones(size(movingPoints,1),1)];
    fixedPoints = [fixedPoints ones(size(fixedPoints,1),1)];
    t1 = fixedPoints\movingPoints;
    t2 = movingPoints\fixedPoints;
    t1(:,3) = [0;0;1];
    t2(:,3) = [0;0;1];
    Tforward(:,:,i) = t1;
    Treverse(:,:,i) = t2;
    tform1 = affine2d(t1);
    tform2 = affine2d(t2);
    movingRegistered = imwarp(moving,tform2,'OutputView',imref2d(size(fixed)));
    
    figure
    subplot(2,2,1)
    imagesc(movingRegistered)
    subplot(2,2,2)
    imagesc(fixed)
    subplot(2,2,3:4)
    imshowpair(fixed, movingRegistered,'Scaling','joint')
end
zoom = [1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0];
save('affinetransform.mat','Tforward','Treverse','zoom')

lm11 = fitlm(zoom,squeeze(Tforward(1,1,:)))
lm12 = fitlm(zoom,squeeze(Tforward(1,2,:)))
lm21 = fitlm(zoom,squeeze(Tforward(2,1,:)))
lm22 = fitlm(zoom,squeeze(Tforward(2,2,:)))
lm31 = fitlm(zoom,squeeze(Tforward(3,1,:)))
lm32 = fitlm(zoom,squeeze(Tforward(3,2,:)))

Model_slope = [lm11.Coefficients.Estimate(2) lm12.Coefficients.Estimate(2) 0;
              lm21.Coefficients.Estimate(2) lm22.Coefficients.Estimate(2) 0;
              lm31.Coefficients.Estimate(2) lm32.Coefficients.Estimate(2) 0];
          
Model_icpt = [lm11.Coefficients.Estimate(1) lm12.Coefficients.Estimate(1) 0;
              lm21.Coefficients.Estimate(1) lm22.Coefficients.Estimate(1) 0;
              lm31.Coefficients.Estimate(1) lm32.Coefficients.Estimate(1) 1];

Model = @(z) z.*Model_slope + Model_icpt;

% one direction is linear, the other is 1/x !
lm11 = fitlm(zoom,squeeze(Treverse(1,1,:)))
lm12 = fitlm(zoom,squeeze(Treverse(1,2,:)))
lm21 = fitlm(zoom,squeeze(Treverse(2,1,:)))
lm22 = fitlm(zoom,squeeze(Treverse(2,2,:)))
lm31 = fitlm(zoom,squeeze(Treverse(3,1,:)))
lm32 = fitlm(zoom,squeeze(Treverse(3,2,:)))

Model_slope = [lm11.Coefficients.Estimate(2) lm12.Coefficients.Estimate(2) 0;
              lm21.Coefficients.Estimate(2) lm22.Coefficients.Estimate(2) 0;
              lm31.Coefficients.Estimate(2) lm32.Coefficients.Estimate(2) 0];
          
Model_icpt = [lm11.Coefficients.Estimate(1) lm12.Coefficients.Estimate(1) 0;
              lm21.Coefficients.Estimate(1) lm22.Coefficients.Estimate(1) 0;
              lm31.Coefficients.Estimate(1) lm32.Coefficients.Estimate(1) 1];

Model = @(z) z.*Model_slope + Model_icpt;


Model(hSI.hRoiManager.scanZoomFactor)

figure
hold on
plot(lm11)
plot(lm12)
plot(lm21)
plot(lm22)
plot(lm31)
plot(lm32)


