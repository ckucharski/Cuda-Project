#define STB_IMAGE_IMPLEMENTATION
#include "stb/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb/stb_image_write.h"
#include <iostream>
#include <stdio.h>

__device__ int getMax(int value1, int value2)
{
	return value1 > value2 ? value1 : value2;
}

__device__ int getMin(int value1, int value2)
{
	return value1 < value2 ? value1 : value2;
}

__device__ int clamp(int value, int minValue, int maxValue)
{
	return getMax( getMin( value, maxValue ), minValue );
}

__device__ int getPosition(int x, int y, int width, int margin, int pixelPosition)
{
	return (x + (y * width)) * margin + pixelPosition; 
}

__device__ void getMaxIndex(int array[], int size, int &maxValue, int &maxIndex)
{
	maxValue = -1; maxIndex = -1;
	for( int i = 0; i <= size; i++ )
	{
		if( maxValue < array[i] )
		{
			maxValue = array[i];
			maxIndex = i;
		}
	}
}

__global__ void setEdgeDetection( unsigned char* output_img, const unsigned char* input_img, int width, int height, int nbBlocks )
{
	int margin = 3;

	int lengthY = (int)(height/nbBlocks)+1;
	int startY = blockIdx.x * lengthY;
	int endY = blockIdx.x * lengthY + lengthY;

	if( endY > height )
		endY = height;
	
	int lengthX = (int)(width/blockDim.x)+1;
	int startX = threadIdx.x * lengthX;
	int endX = threadIdx.x * lengthX + lengthX;

	if( endX > width )
		endX = width;
	
	float kernel[9] = {
		1.0, 0.0, -1.0,
		0.0, 0.0, 0.0,
		-1.0, 0.0, 1.0 
	};
	float kernelDiv = 1.0f;

	for( int x = startX; x < endX; x++ )
	{
		for( int y = startY; y < endY; y++ )
		{
			int currentIndex = getPosition(x, y, width, margin, 0);
			float countR = 0;
			float countG = 0;
			float countB = 0;

			int n = 0;

			for( int i = -1; i <= 1; i++ )
			{
				if( y+i < 0 || y+i >= height )
					continue;

				for( int j = -1; j <= 1; j++)
				{
					if( x+i < 0 || x+i >= width )
						continue;

					int currentIndex2 = getPosition(x+j, y+i, width, margin, 0);
					countR += input_img[currentIndex2] / 255.0f * kernel[n];
					countG += input_img[currentIndex2+1] / 255.0f * kernel[n];
					countB += input_img[currentIndex2+2] / 255.0f * kernel[n];
					n++;
				}
			}

			countR *= kernelDiv;
			countG *= kernelDiv;
			countB *= kernelDiv;

			output_img[currentIndex] = clamp(255 - countR * 255 * 20, 0, 255);
			output_img[currentIndex+1] = clamp(255 - countG * 255 * 20, 0,255);  
			output_img[currentIndex+2] = clamp(255 - countB * 255 * 20, 0, 255);
		}
	}	
}

__global__ void setOilFilter(unsigned char* output_img, const unsigned char* input_img, int width, int height, int radius, int intensity, int nbBlocks)
{
	int margin = 3;

	int lengthY = (int)(height/nbBlocks)+1;
	int startY = blockIdx.x * lengthY;
	int endY = blockIdx.x * lengthY + lengthY;

	if( endY > height )
		endY = height;
	
	int lengthX = (int)(width/blockDim.x)+1;
	int startX = threadIdx.x * lengthX;
	int endX = threadIdx.x * lengthX + lengthX;

	if( endX > width )
		endX = width;

	for( int x = startX; x < endX; x++ )
	{
		for( int y = startY; y < endY; y++)
		{
			int currentIndex = getPosition(x, y, width, margin, 0);
			int intensityCount[255] = {0};
			int intensityR[255] = {0};
			int intensityG[255] = {0};
			int intensityB[255] = {0};

			for( int i = -radius; i <= radius; i++ )
			{
				if( y+i < 0 || y+i >= height )
					continue;

				for( int j = -radius; j <= radius; j++ )
				{
					if( x+j < 0 || x+j >= width )
						continue;

					int currentIndex2 = getPosition(x+j, y+i, width, margin, 0);
					int R = input_img[currentIndex2];
					int G = input_img[currentIndex2+1];
					int B = input_img[currentIndex2+2];

					int currentIntensity = (((R+G+B)/3.0)*intensity)/255.0;
				
					intensityCount[currentIntensity]++;
					intensityR[currentIntensity] += R;
					intensityG[currentIntensity] += G;
					intensityB[currentIntensity] += B;
				}	
			}
			int maxValue = 0; int maxIndex = 0;
			
			getMaxIndex(intensityCount, intensity, maxValue, maxIndex);
			output_img[currentIndex] = clamp(intensityR[maxIndex]/maxValue, 0, 255);
			output_img[currentIndex+1] = clamp(intensityG[maxIndex]/maxValue, 0, 255);
			output_img[currentIndex+2] = clamp(intensityB[maxIndex]/maxValue, 0, 255);
		}
	}
}

__global__ void addEffect( unsigned char* output_img, unsigned char* input_img, int width, int height, int nbBlocks)
{
	int lengthY = (int)(height/nbBlocks)+1;
	int startY = blockIdx.x * lengthY;
	int endY = blockIdx.x * lengthY + lengthY;

	if( endY > height )
		endY = height;
	
	int lengthX = (int)(width/blockDim.x)+1;
	int startX = threadIdx.x * lengthX;
	int endX = threadIdx.x * lengthX + lengthX;

	if( endX > width )
		endX = width;

	for( int x = startX; x < endX; x++ )
	{
		for( int y = startY; y < endY; y++ )
		{
			int currentIndex = getPosition(x, y, width, 3, 0);
			if( (input_img[currentIndex] + input_img[currentIndex+1] + input_img[currentIndex+2])/3 < 20)
			{
				output_img[currentIndex] = input_img[currentIndex];
				output_img[currentIndex+1] = input_img[currentIndex+1];
				output_img[currentIndex+2] = input_img[currentIndex+2];

				for( int i = -4; i <= 4; i++ )
				{
					for( int j = -4; j <= 4; j++ )
					{
						if( x+i < 0 || x+i > width || y+j < 0 || y+j > height )
							continue;

						int neighbourIndex = getPosition( x+i, y+j, width, 3, 0);

						if( neighbourIndex < 0 || neighbourIndex + 2 > width*height*3)
							continue;
					
						output_img[neighbourIndex] = 0;
						output_img[neighbourIndex+1] = 0;
						output_img[neighbourIndex+2] = 0;
					}
					
				}
			}
		}
		
	}

}

int main()
{
	int width, height, n;
	unsigned char* sourceImg = stbi_load("Photos/01.jpg", &width, &height, &n, 3);
	int nbBlocks = 13; int nbThreads = 1024;
	
	unsigned char* inputImg, *inputImg2, *outputImg, *tmpOutput;
	cudaMalloc((void**) &inputImg, width * height * n * sizeof(unsigned char));
	cudaMemcpy(inputImg, sourceImg, width * height * n * sizeof(unsigned char), cudaMemcpyHostToDevice);

	cudaMallocManaged(&outputImg, width * height * n * sizeof(unsigned char));
	cudaMallocManaged(&tmpOutput, width * height * n * sizeof(unsigned char));
	
	// OIL FILTER
	setOilFilter<<<nbBlocks,nbThreads>>>(outputImg, inputImg, width, height, 10, 20, nbBlocks);
	cudaDeviceSynchronize();

	cudaMalloc((void**) &inputImg2, width * height * n * sizeof(unsigned char));
	cudaMemcpy(inputImg2, outputImg, width * height * n * sizeof(unsigned char), cudaMemcpyDeviceToDevice);

	// EDGE DETECTION
	setEdgeDetection<<<nbBlocks,nbThreads>>>(tmpOutput, inputImg2, width, height, nbBlocks);
	cudaDeviceSynchronize();

	// FUSION
	addEffect<<<nbBlocks,nbThreads>>>(outputImg, tmpOutput, width, height, nbBlocks);
	cudaDeviceSynchronize();

	stbi_write_png("exempleCuda.png", width, height, n, outputImg, n*width);
	
	cudaFree(inputImg2);
	cudaFree(tmpOutput);
	cudaFree(outputImg);
	cudaFree(inputImg);

	return 0;
}
