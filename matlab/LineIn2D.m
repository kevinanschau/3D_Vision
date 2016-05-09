% =========================================================================
%> @brief Class LineIn2D
%>
%> 
%>
%> 
%>
% =========================================================================
classdef LineIn2D < handle
    properties
        startPointIP             % IP stands for image plane
        endPointIP
        
        sampledPoints@Pointcloud2D
        
    end
    
    methods
        %> @brief
        %>
        %> @retval obj Object of class LineIn2D
        function obj = LineIn2D(lineIn3D, focalLengthMatrix)
            homogeneousStartPointIP = focalLengthMatrix * lineIn3D.startPoint.trueCoordinatesInWorldFrame;
            homogeneousEndPointIP = focalLengthMatrix * lineIn3D.endPoint.trueCoordinatesInWorldFrame;
            
            obj.startPointIP = homogeneousStartPointIP(1:2);
            obj.endPointIP = homogeneousEndPointIP(1:2);
        end % Constructor LineIn2D end
        
        
        %> @brief
        %>
        %> @param
        function samplingline(this, numberOfSamples)
    
            % creation of samples of a line
            line = this.endPointIP - this.startPointIP;
            linelength = norm(line);
            direction = 1 / linelength * line;

            lengthstep = linelength / numberOfSamples;
            %this.sampledPoints = assignPointToPointCloud(numberOfSamples);
            sampledpoints = [];
            for i= 1:numberOfSamples+1
               sampledPoint = this.startPointIP + (i-1) * lengthstep * direction;
               sampledpoints = [sampledpoints;sampledPoint' 1];
            end
            
            this.sampledPoints = Pointcloud2D(sampledpoints);
            
            
        end % sampling LineIn2D end
        
        function measurementprocessing(this, kappa, p, imageToPixelMatrix, noiseType, mean, variance)
            
            % add distortion and pixel noise to these samples
            this.sampledPoints.addDistortion(kappa,p);
            this.sampledPoints.calculateHomoegenousDistortedPixelPoints(imageToPixelMatrix);
            this.sampledPoints.setDistortedPixelCoordinatesFromHomogeneousCoordinates();
            this.sampledPoints.addPixelNoise(noiseType, mean, variance);
            
            % back projection and undistortion of these sampels
            this.sampledPoints.transformFromPixelToImage(imageToPixelMatrix);
            this.sampledPoints.undistortPointCloud2D();

            % fit a line through these samples
            estimatedSamples = linearRegression(this.sampledPoints);
            
        end
        
        %> @brief
        %>
        %> @param
        function plotProjectedLine(this)
            % Concatenate the starting and end point
            X = [this.startPointIP(1), this.endPointIP(1)];
            Y = [this.startPointIP(2), this.endPointIP(2)];
            % Plot the line
            plot(X ,Y ,'Color','black');
        end % plotNoisyLine() end
        
    end % methods end
end % classdef LineIn2D end


        

