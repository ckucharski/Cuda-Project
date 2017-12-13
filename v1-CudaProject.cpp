#include <iostream>

#define STB_IMAGE_IMPLEMENTATION
#include "stb/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb/stb_image_write.h"


void getMaxIndex(int array[], int size, int &maxValue, int &maxIndex)
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
	assert( maxValue != -1 && maxIndex != -1 );
}

int clamp( int value, int minValue, int maxValue )
{
	return std::max( std::min( value, maxValue ), minValue );
}

int getPosition( int x, int y, int width, int margin, int pixelPosition)
{
	return (x + (y * width)) * margin + pixelPosition; 

}

void addEffect( unsigned char* source, unsigned char* imgToAdd, int width, int height)
{
	unsigned char* sourceCopy = new unsigned char[ width * height * 3 ];
	memcpy( sourceCopy, source, width * height * 3 );

	for( int x = 0; x < width; x++ )
	{
		for( int y = 0; y < height; y++ )
		{
			int currentIndex = getPosition(x, y, width, 3, 0);
			if( (imgToAdd[currentIndex] + imgToAdd[currentIndex+1] + imgToAdd[currentIndex+2])/3 < 20)
			{
				source[currentIndex] = imgToAdd[currentIndex];
				source[currentIndex+1] = imgToAdd[currentIndex+1];
				source[currentIndex+2] = imgToAdd[currentIndex+2];

				for( int i = -4; i <= 4; i++ )
				{
					for( int j = -4; j <= 4; j++ )
					{
						if( x+i < 0 || x+i > width || y+j < 0 || y+j > height )
							continue;

						int neighbourIndex = getPosition( x+i, y+j, width, 3, 0);

						if( neighbourIndex < 0 || neighbourIndex + 2 > width*height*3)
							continue;
					
						source[neighbourIndex] = 0;
						source[neighbourIndex+1] = 0;
						source[neighbourIndex+2] = 0;
					}
					
				}
			}
		}
		
	}

}

void setOilFilter( unsigned char* newImg, int width, int height, int radius, int intensity )
{
	unsigned char* imgCopy = newImg;
	int margin = 3;

	for( int x = radius; x < width - radius; x++ )
	{
		for( int y = radius; y < height - radius; y++)
		{
			int currentIndex = getPosition(x, y, width, margin, 0);
			int intensityCount[255] = {0};
			int intensityR[255] = {0};
			int intensityG[255] = {0};
			int intensityB[255] = {0};

			for( int i = -radius; i <= radius; i++ )
			{
				for( int j = -radius; j <= radius; j++ )
				{
					int currentIndex2 = getPosition(x+j, y+i, width, margin, 0);
					int R = imgCopy[currentIndex2];
					int G = imgCopy[currentIndex2+1];
					int B = imgCopy[currentIndex2+2];

					int currentIntensity = (((R+G+B)/3.0)*intensity)/255.0;

					intensityCount[currentIntensity]++;
					intensityR[currentIntensity] += R;
					intensityG[currentIntensity] += G;
					intensityB[currentIntensity] += B;
				}			
			}
					
			int maxValue = 0; int maxIndex = 0;
			
			getMaxIndex(intensityCount, intensity, maxValue, maxIndex);
			newImg[currentIndex] = clamp(intensityR[maxIndex]/maxValue, 0, 255);
			newImg[currentIndex+1] = clamp(intensityG[maxIndex]/maxValue, 0, 255);
			newImg[currentIndex+2] = clamp(intensityB[maxIndex]/maxValue, 0, 255);
		}
	}
}


void setEdgeDetection( unsigned char* newImg, int width, int height )
{
	int margin = 3;

	unsigned char* imgCopy = new unsigned char[ width * height * margin ];
	memcpy( imgCopy, newImg, width * height * margin );

	/*float kernel[9] = {
		0.0, 0.0, 0.0,
		0.0, 1.0, 0.0,
		0.0, 0.0, 0.0
	};
	float kernelDiv = 1.0f;*/

	/*float kernel[9] = {
		1.0, 2.0, 1.0,
		2.0, 4.0, 2.0,
		1.0, 2.0, 1.0
	};
	float kernelDiv = 1.0f / 16.0f;*/

	
	float kernel[9] = {
		1.0, 0.0, -1.0,
		0.0, 0.0, 0.0,
		-1.0, 0.0, 1.0 
	};
	float kernelDiv = 1.0f;

	/*float kernel[9] = {
		-1.0, -1.0, -1.0,
		-1.0, 8.0, -1.0,
		-1.0, -1.0, -1.0 
	};
	float kernelDiv = 1.0f;*/

	for( int y = 1; y < height - 1; y++ )
	{
		for( int x = 1; x < width - 1; x++ )
		{
			int currentIndex = getPosition(x, y, width, margin, 0);
			float countR = 0;
			float countG = 0;
			float countB = 0;

			int n = 0;

			for( int j = -1; j <= 1; j++ )
			{
				for( int i = -1; i <= 1; i++)
				{
					int currentIndex2 = getPosition(x+i, y+j, width, margin, 0);
					countR += imgCopy[currentIndex2] / 255.0f * kernel[n];
					countG += imgCopy[currentIndex2+1] / 255.0f * kernel[n];
					countB += imgCopy[currentIndex2+2] / 255.0f * kernel[n];
					n++;
				}
			}

			countR *= kernelDiv;
			countG *= kernelDiv;
			countB *= kernelDiv;

			newImg[currentIndex] = clamp(255 - countR * 255 * 20, 0, 255);
			newImg[currentIndex+1] = clamp(255 - countG * 255 * 20, 0,255);  
			newImg[currentIndex+2] = clamp(255 - countB * 255 * 20, 0, 255);
			
		}
	}	
}



int main()
{
	int width, height, n;
	unsigned char* imgData = stbi_load("Photos/04.jpg", &width, &height, &n, 3);
	
	setOilFilter(imgData, width, height, 10, 20);

	unsigned char* imgCopy = new unsigned char[ width * height * 3 ];
	memcpy( imgCopy, imgData, width * height * 3 );
	setEdgeDetection(imgCopy, width, height);

	addEffect(imgData, imgCopy, width, height);

	stbi_write_png("exemple.png", width, height, n, imgData, n*width);

	stbi_image_free(imgData);

	return 0;
}
