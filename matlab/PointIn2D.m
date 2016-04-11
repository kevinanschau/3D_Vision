% =========================================================================
%> @brief Class PointIn2D stores projected coordinates of a corresponding PointIn3D and adds pixel noise to itself
%>
%>
%>
% =========================================================================
classdef PointIn2D < handle
    properties

        % Coordinates in camera frame
        projectedCoordinates                                    %> @param projectedCoordinates Coordinates of the 3D to 2D projection
        homogeneousProjectedCoordinates                         %> @param homogeneousProjectedCoordinates Homogeneous coordinates of the 3D to 2D projection
        noisyCoordinates                                        %> @param noisyCoordinates Coordinates with pixel noise
        homogeneousNoisyCoordinates                             %> @param homogeneousNoisyCoordinates Homogeneous coordinates with pixel noise
        
        noisyCoordinatesInCameraFrame                           %> @param noisyCoordinatesInCameraFrame u-v coordinates
        homogeneousNoisyCoordinatesInCameraFrame                %> @param noisyCoordinatesInCameraFrame Homogeneous u-v coordinates      
        
        distortedNoisyCoordinatesInCameraFrame                  %> @param distortedNoisyCoordinatesInCameraFrame Distorted u-v coordinates
        homogeneousDistortedNoisyCoordinatesInCameraFrame       %> @param distortedNoisyCoordinatesInCameraFrame Homogeneous distorted u-v coordinates
        
        homogeneousDistortedPixelCoordinates                    %> @param homogeneousDistortedPixelCoordinates Homogeneous distorted pixel coordinates
        distortedPixelCoordinates                               %> @param distortedPixelCoordinates Distorted pixel coordinates (x,y)
        
        homogeneousNoisyPixelCoordinates                        %> @param homogeneousNoisyPixelCoordinates Homogeneous pixel coordinates of distorted projected points
        noisyPixelCoordinates                                   %> @param NoisyPixelCoordinates Pixel coordinates of distorted projected points
        
        backProjectionFromPixelToImageCoordinates               %> @param backProjectionFromPixelToImageCoordinates after adding pixel noise we transform pixel coord. back to euclidean image coord.
        homogeneousBackProjectionFromPixelToImageCoordinates    %> @param homogeneousBackProjectionFromPixelToImageCoordinates transformation from pixel to homogeneous image coordinates after pixel noise
        
        % Noise in pixel space
        pixelNoiseMean                                          %> @param Vector of means for the anisotropic Gaussian noise of the 2D point
        pixelNoiseVariance                                      %> @param Vector of variances for the anisotropic Gaussian noise of the 2D point
    end % properties end
    
    methods
        %> @brief Constructor projects the true 3D points in camera frame into the focal plane of the camera
        %>
        %> Formula: x = F*X_C
        %> x := homogeneous coordinates of a 2D point
        %> X_C := coordinates of a noisy 3D point in camera frame
        %> F := Transformation matrix into focal plane, F = diag([f, f, 1])
        %>
        %> @param noisyPointIn3D A noisy point in 3D
        %> @param focalLengthMatrix Transformation matrix into focal plane
        %> @param cameraTruePose Ground truth of camera
        %>
        %> @retval obj An object of class PointIn2D

        % First, do the coordinates in pixel space
        function obj = PointIn2D(noisyPointIn3D, focalLengthMatrix)
            % Project true 3D points in camera frame to the focal plane
            obj.homogeneousProjectedCoordinates = focalLengthMatrix * noisyPointIn3D.trueCoordinatesInCameraFrame;
            % Normalize to get homogeneous representation
            obj.homogeneousProjectedCoordinates = obj.homogeneousProjectedCoordinates / obj.homogeneousProjectedCoordinates(3);
            
            % Get euclidean coordinates from homogeneous coordinates
            obj.projectedCoordinates = obj.homogeneousProjectedCoordinates(1:2);
            obj.noisyCoordinatesInCameraFrame = obj.homogeneousNoisyCoordinatesInCameraFrame(1:2);
            
        end % Constructor end
        
        % 1. add distortion
        %> @brief Add distortion to u,v coordinates
        %>
        %> @param this Pointer to object
        %> @param kappa Radial distortion parameters 3-dimensional vector
        %> @param p Tangential distortion parameters 2-dimensional vector
        function addDistortion(this, kappa, p)
      
           uvCoordinates = this.noisyCoordinatesInCameraFrame;
           %centerOfDistortion = [0;0];
           radiusSquared = uvCoordinates(1)^2 + uvCoordinates(2)^2;
           this.distortedNoisyCoordinatesInCameraFrame(1) = (1 + kappa(1) * radiusSquared + kappa(2) * radiusSquared^2 + kappa(3) * radiusSquared^3) * uvCoordinates(1) ...
               + 2 * p(1) * uvCoordinates(1) * uvCoordinates(2) + p(2) * (radiusSquared + 2 * uvCoordinates(1)^2);
           this.distortedNoisyCoordinatesInCameraFrame(2) = (1 + kappa(1) * radiusSquared + kappa(2) * radiusSquared^2 + kappa(3) * radiusSquared^3) * uvCoordinates(2) ...
               + 2 * p(2) * uvCoordinates(1) * uvCoordinates(2) + p(1) * (radiusSquared + 2 * uvCoordinates(2)^2);
           this.homogeneousDistortedNoisyCoordinatesInCameraFrame = [ this.distortedNoisyCoordinatesInCameraFrame(1); this.distortedNoisyCoordinatesInCameraFrame(2);1];
        end % addDistortion() end
        
        
        % 2. calculate homogeneous distorted points in xy (pixel) coordinates 
        %> @brief Calculate the homogeneous distorted points in uv coordinates
        %>
        %> @param this Pointer to PointIn2D object 
        %> @param imagetoPixelCoordinatesTrafo [camera.kx, camera.skew, camera.x0; 0, camera.ky, camera.y0; 0, 0, 1];
        function calculateHomoegeneousDistortedPixelCoordinates(this, imageToPixelMatrix)
            pixelCoordinatesDistorted = [this.distortedNoisyCoordinatesInCameraFrame(1); this.distortedNoisyCoordinatesInCameraFrame(2); 1]; %transformFromEuclideanToHomogeneous(this.distortedNoisyCoordinatesInCameraFrame);
            this.homogeneousDistortedPixelCoordinates = imageToPixelMatrix * pixelCoordinatesDistorted;
        end % calculateHomoegeneousDistortedPixelCoordinates() end 

        
        % 3. calculate given homogeneous to euclidean distorted points in uv coordinates
        %> @brief Calculate the euclidean distorted points in uv coordinates (given homogeneous distorted pixel points)
        %>
        %> @param this Pointer to object

        function setDistortedPixelCoordinatesFromHomogeneousCoordinates(this)
            this.distortedPixelCoordinates = this.homogeneousDistortedPixelCoordinates(1:2);
        end % setDistortedPixelCoordinatesFromHomogeneousCoordinates() end

        % 4. add pixel noise
        %> @brief Add pixel noise to this 2D point
        %>
        %> @param this Pointer to object
        %> @param noiseType String type of noise
        %> @param mean Mean of gaussian distribution in x- and y-direction
        %> @param variance Variance of gaussian distribution in x- and y-direction
        function addPixelNoise(this, noiseType, mean, variance)
            % discrete uniformly distributed noise
            if strcmp(noiseType,'uniformly')
                % genereate noise in x- and y-direction
                noiseInPixelX = 2*variance(1)*rand() - variance(1);
                noiseInPixelY = 2*variance(2)*rand() - variance(2);
            % gaussian distributed noise
            elseif strcmp(noiseType,'gaussian')
                % generate noise in x- and y-direction
                noiseInPixelX = normrnd(mean(1), variance(1));
                noiseInPixelY = normrnd(mean(2), variance(2));
            end %if end
            
            % add noise to pixel coordinates
            this.homogeneousNoisyPixelCoordinates(1) = this.homogeneousDistortedPixelCoordinates(1) + noiseInPixelX;
            this.homogeneousNoisyPixelCoordinates(2) = this.homogeneousDistortedPixelCoordinates(2) + noiseInPixelY;
            this.homogeneousNoisyPixelCoordinates(3) = 1;
            this.homogeneousNoisyPixelCoordinates = this.homogeneousNoisyPixelCoordinates';
             % extract euclidean noisy pixel coordinates from homogeneous coordinates
            this.noisyPixelCoordinates = this.homogeneousNoisyPixelCoordinates(1:2);
        end % addPixelNoise() end
        
        % 5. back projection to image coordinates
        %> @brief Transform from pixel coordinates (x,y) to image coordinates (u,v)
        %> 
        %> @param this Pointer to object
        %> @param calibrationMatrix calibration matrix of camera
        function transformFromPixelToImage(this, calibrationMatrix)
           this.homogeneousBackProjectionFromPixelToImageCoordinates = calibrationMatrix \ this.homogeneousNoisyPixelCoordinates;
           this.backProjectionFromPixelToImageCoordinates = this.homogeneousBackProjectionFromPixelToImageCoordinates(1:2);
        end % transformFromPixelToImage() end
        
        % 6. undistortion
       %%%%%% has to be done
        
        %> @brief Returns coordinates of this object of PointIn2D
        %>
        %> @param this Pointer to object
        %>
        %> @retval projCoord Projected coordinates of 2D point
        %> @retval homProjCoord Homogeneous coordinates of 2D point
        %> @retval noisyCoord Noisy coordinates of 2D point
        %> @retval homNoisyCoord Homogeneous coordinates of noisy 2D point
        function [projCoord, homProjCoord, noisyCoord, homNoisyCoord] = getCoordinates(this)
            projCoord = this.projectedCoordinates;
            homProjCoord = this.homogeneousProjectedCoordinates;
            noisyCoord = this.noisyCoordinates;
            homNoisyCoord = this.homogeneousNoisyCoordinates;
        end % getCoordinates() end

        %> @param this Pointer to object
        %> @param mean Vector of means, in camera frame
        function setMean(this, mean)
            this.pixelNoiseMean = mean;
        end % setMean() end
        
        %> @param mean Vector of variances
        function setVariance(this, variance)
            this.pixelNoiseVariance = variance;
        end % setVariance() end

        %> @brief Helper function
        %>
        %> @param this Pointer to PointIn2D object
        %> @param variance Variance of gaussian distribution
        %> @param pixelWindowInterval Half interval in pixel of window
        function discreteRandomVariable = generateDRV(this, variance, pixelWindowInterval)
            % Generate random uniformly distributed variable
            u = rand();
            
            % Desired probability density function
            pdf = makedist('Normal',0,variance);
            
            % Cumulative distribution function
            F = cdf(pdf,-pixelWindowInterval:pixelWindowInterval);
            
            % Find discrete random variable
            DRV = find(F <= u);
            
            % find last index at which F <= u and u < F
            if (isempty(DRV))
                discreteRandomVariable = - pixelWindowInterval;
            else
                discreteRandomVariable = DRV(end) - pixelWindowInterval;
            end
        end % generateDRV() end
    end % methods end
end % classdef end