#include <iostream>
#include "bmp_hdlr.h"
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#define NUM_THREADS 512

int canvas_r[bmp_size][bmp_size], canvas_g[bmp_size][bmp_size], canvas_b[bmp_size][bmp_size];
int h, w;
bool open = true;

bool InitCUDA()
{
	int count;

	cudaGetDeviceCount(&count);
	if (count == 0) {
		fprintf(stderr, "There is no device.\n");
		return false;
	}

	int i;
	for (i = 0; i < count; i++) {
		cudaDeviceProp prop;
		if (cudaGetDeviceProperties(&prop, i) == cudaSuccess) {
			if (prop.major >= 1) {
				break;
			}
		}
	}

	if (i == count) {
		fprintf(stderr, "There is no device supporting CUDA 1.x.\n");
		return false;
	}

	cudaSetDevice(i);

	return true;
}

__global__ static void monochrome(int* r,int* g, int* b ,int num ,int ht ,int wt)
{
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	const int idx = bid * blockDim.x + tid;
	const int row = idx / num;
	const int col = idx % num;
	if (row < ht && col < wt)
	{
		int y = (299 * r[row*num + col] + 587 * g[row*num + col] + 114 * b[row*num + col]) / 1000;
		r[row*num + col] = g[row*num + col] = b[row*num + col] = y;
	}
}

__global__ static void blur(int* r, int* g, int* b, int num, int ht ,int wt)
{
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	const int idx = bid * blockDim.x + tid;
	const int row = idx / num;
	const int col = idx % num;
	if (row < ht && col < wt)
	{
		int rr = 0, gg = 0, bb = 0, cnt = 0;
		for (int a = 0; a < 9; a++)
			for (int c = 0; c < 9; c++)
				if (row - 4 + a > -1 && row - 4 + a < ht && col - 4 + c > -1 && col - 4 + c < wt)
				{
					rr += r[(row - 4 + a) * num + col - 4 + c];
					gg += g[(row - 4 + a) * num + col - 4 + c];
					bb += b[(row - 4 + a) * num + col - 4 + c];
					cnt++;
				}
		r[row*num + col] = rr / cnt;
		g[row*num + col] = gg / cnt;
		b[row*num + col] = bb / cnt;
	}
}

__global__ static void moreblur(int* r, int* g, int* b, int num,int ht ,int wt)
{
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	const int idx = bid * blockDim.x + tid;
	const int row = idx / num;
	const int col = idx % num;
	if (row < ht && col < wt)
	{
		int rr = 0, gg = 0, bb = 0, cnt = 0, rrr = 0, ggg = 0, bbb = 0, x = 0;
		while (x < 4)
		{
			int i, j;
			if (x == 0) i = j = -5;
			else if (x == 1) i = 5;
			else if (x == 2) j = 5;
			else if (x == 3) i = -5;
			for (int a = 0; a < 9; a++)
				for (int c = 0; c < 9; c++)
					if (row - 4 + a+i > -1 && row - 4 + a+i < ht && col - 4 + c+j > -1 && col - 4 + c+j < wt)
					{
						rr += r[(row - 4 + a + i) * num + col - 4 + c + j];
						gg += g[(row - 4 + a + i) * num + col - 4 + c + j];
						bb += b[(row - 4 + a + i) * num + col - 4 + c + j];
						cnt++;
					}
			rrr += rr / cnt;
			ggg += gg / cnt;
			bbb += bb / cnt;
			x++;
		}
		r[row*num + col] = rrr / 4;
		g[row*num + col] = ggg / 4;
		b[row*num + col] = bbb / 4;
	}
}

__global__ static void focusblur(int* r, int* g, int* b, int num, int ht, int wt, int radius)
{
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	const int idx = bid * blockDim.x + tid;
	const int row = idx / num;
	const int col = idx % num;
	if (row < ht && col < wt)
	{
		const int dis = (row - radius)*(row - radius) + (col - radius)*(col - radius);
		const int diff = dis / (radius*radius);
		int rr = 0, gg = 0, bb = 0, cnt = 0;
		for (int ti = -diff; ti <= diff; ++ti) {
			for (int tj = -diff; tj <= diff; ++tj) {
				if (0 <= row + ti && row + ti < ht && 0 <= col + tj && col + tj < wt) {
					rr += r[(row + ti)*num + col + tj];
					gg += g[(row + ti)*num + col + tj];
					bb += b[(row + ti)*num + col + tj];
					++cnt;
				}
			}
		}
		r[row*bmp_size + col] = rr / cnt;
		g[row*bmp_size + col] = gg / cnt;
		b[row*bmp_size + col] = bb / cnt;
	}
}

__global__ static void smallsize(int* r, int* g, int* b, int num, int ht, int wt, float n)
{
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	const int idx = bid * blockDim.x + tid;
	const int row = idx / num;
	const int col = idx % num;
	if (row < ht/n && col < wt/n)
	{
		int pos = row * num * n + col * n;
		r[row*num + col] = r[pos];
		g[row*num + col] = g[pos];
		b[row*num + col] = b[pos];
	}
}

int main() {

	if (!open)
		return 0;

	if (!InitCUDA()) {
		return 0;
	}
	
	int *gpur, *gpug, *gpub;
	cudaMalloc((void**)&gpur, sizeof(int) * bmp_size * bmp_size);
	cudaMalloc((void**)&gpug, sizeof(int) * bmp_size * bmp_size);
	cudaMalloc((void**)&gpub, sizeof(int) * bmp_size * bmp_size);
	
	cudaMemcpy2D(gpur, sizeof(int) * bmp_size, canvas_r, sizeof(int) * bmp_size, sizeof(int) * bmp_size, bmp_size, cudaMemcpyHostToDevice);
	cudaMemcpy2D(gpug, sizeof(int) * bmp_size, canvas_g, sizeof(int) * bmp_size, sizeof(int) * bmp_size, bmp_size, cudaMemcpyHostToDevice);
	cudaMemcpy2D(gpub, sizeof(int) * bmp_size, canvas_b, sizeof(int) * bmp_size, sizeof(int) * bmp_size, bmp_size, cudaMemcpyHostToDevice);

	int i;
	std::cout << "what do tou want to do?\n1.monochrome\n2.blur\n3.more blur\n4.focus blur\n5.\n:";
	std::cin >> i;
	if (i == 1)
	{
		int blocks = (bmp_size + NUM_THREADS - 1) / NUM_THREADS;
		monochrome << <blocks * bmp_size, NUM_THREADS >> > (gpur, gpug, gpub, bmp_size,h ,w);
	}
	else if (i == 2)
	{
		int blocks = (bmp_size + NUM_THREADS - 1) / NUM_THREADS;
		blur << <blocks * bmp_size, NUM_THREADS >> > (gpur, gpug, gpub, bmp_size,h,w);
	}
	else if (i == 3)
	{
		int blocks = (bmp_size + NUM_THREADS - 1) / NUM_THREADS;
		moreblur << <blocks * bmp_size, NUM_THREADS >> > (gpur, gpug, gpub, bmp_size, h, w);
	}
	else if (i == 4)
	{
		int radius;
		if (h > w) radius = w / 3; else radius = h / 3;
		int blocks = (bmp_size + NUM_THREADS - 1) / NUM_THREADS;
		focusblur << <blocks * bmp_size, NUM_THREADS >> > (gpur, gpug, gpub, bmp_size, h, w, radius);
	}
	else if (i == 5)
	{
		float num = 1000;
		while (num > 100 || num < 1)
		{
		std::cout << "how many % smaller?(1~100):";
		std::cin >> num;
		}
		num = 100 / num;
		int blocks = (bmp_size + NUM_THREADS - 1) / NUM_THREADS;
		smallsize << <blocks * bmp_size, NUM_THREADS >> > (gpur, gpug, gpub, bmp_size, h, w, num);
		h /= num;
		w /= num;
		std::cout << h << " " << w << std::endl;
	}

	cudaMemcpy2D(canvas_r, sizeof(int) * bmp_size, gpur, sizeof(int) * bmp_size, sizeof(int) * bmp_size, bmp_size, cudaMemcpyDeviceToHost);
	cudaMemcpy2D(canvas_g, sizeof(int) * bmp_size, gpug, sizeof(int) * bmp_size, sizeof(int) * bmp_size, bmp_size, cudaMemcpyDeviceToHost);
	cudaMemcpy2D(canvas_b, sizeof(int) * bmp_size, gpub, sizeof(int) * bmp_size, sizeof(int) * bmp_size, bmp_size, cudaMemcpyDeviceToHost);


	return 0;
}
