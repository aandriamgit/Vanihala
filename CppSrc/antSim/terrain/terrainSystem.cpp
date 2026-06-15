#include "terrainSystem.hpp"

static void	generateHeight(terrain &t)
{
	t.height.resize(getVertMaxIndex(t), 1);
}

static void	generateVertices(terrain &t)
{
	const int	pointsPerRow = getPointsPerRow(t);
	const int	totalPoints = getVertMaxIndex(t);
	float		*vertPtr;
	int			index;
	int			heightIndex;

	t.vertices.resize(totalPoints * 3);
	vertPtr = t.vertices.data();
	index = 0;
	for (int z = 0; z <= t.mapSize; ++z)
	{
		for (int x = 0; x <= t.mapSize; ++x)
		{
			heightIndex = z * pointsPerRow + x;
			vertPtr[index++] = x;
			vertPtr[index++] = t.height[heightIndex];
			vertPtr[index++] = z;
		}
	}
}

static void	generateNormals(terrain &t)
{
	const int	totalPoints = getVertMaxIndex(t);
	const int	pointsPerRow = getPointsPerRow(t);
	int			tl;
	int			tr;
	int			bl;
	int			br;
	float		dx1;
	float		dy1;
	float		dz1;
	float		dx2;
	float		dy2;
	float		dz2;
	float		dx3;
	float		dy3;
	float		dz3;
	float		dx4;
	float		dy4;
	float		dz4;
	float		nx;
	float		ny;
	float		nz;
	float		*normPtr;
	float		*posPtr;
	int			idx;
	float		len;
	const float	invLen = 1.0f / len;

	t.normals.resize(totalPoints * 3);
	normPtr = t.normals.data();
	posPtr = t.vertices.data();
	std::memset(normPtr, 0, totalPoints * 3 * sizeof(float));
	for (int z = 0; z < t.mapSize; ++z)
	{
		for (int x = 0; x < t.mapSize; ++x)
		{
			tl = (z * pointsPerRow + x) * 3;
			tr = tl + 3;
			bl = tl + pointsPerRow * 3;
			br = bl + 3;
			dx1 = posPtr[tr + 0] - posPtr[tl + 0];
			dy1 = posPtr[tr + 1] - posPtr[tl + 1];
			dz1 = posPtr[tr + 2] - posPtr[tl + 2];
			dx2 = posPtr[bl + 0] - posPtr[tl + 0];
			dy2 = posPtr[bl + 1] - posPtr[tl + 1];
			dz2 = posPtr[bl + 2] - posPtr[tl + 2];
			nx = dy1 * dz2 - dz1 * dy2;
			ny = dz1 * dx2 - dx1 * dz2;
			nz = dx1 * dy2 - dy1 * dx2;
			normPtr[tl + 0] += nx;
			normPtr[tl + 1] += ny;
			normPtr[tl + 2] += nz;
			normPtr[tr + 0] += nx;
			normPtr[tr + 1] += ny;
			normPtr[tr + 2] += nz;
			normPtr[bl + 0] += nx;
			normPtr[bl + 1] += ny;
			normPtr[bl + 2] += nz;
			dx3 = posPtr[br + 0] - posPtr[tr + 0];
			dy3 = posPtr[br + 1] - posPtr[tr + 1];
			dz3 = posPtr[br + 2] - posPtr[tr + 2];
			dx4 = posPtr[bl + 0] - posPtr[tr + 0];
			dy4 = posPtr[bl + 1] - posPtr[tr + 1];
			dz4 = posPtr[bl + 2] - posPtr[tr + 2];
			nx = dy3 * dz4 - dz3 * dy4;
			ny = dz3 * dx4 - dx3 * dz4;
			nz = dx3 * dy4 - dy3 * dx4;
			normPtr[tr + 0] += nx;
			normPtr[tr + 1] += ny;
			normPtr[tr + 2] += nz;
			normPtr[br + 0] += nx;
			normPtr[br + 1] += ny;
			normPtr[br + 2] += nz;
			normPtr[bl + 0] += nx;
			normPtr[bl + 1] += ny;
			normPtr[bl + 2] += nz;
		}
	}
	for (int i = 0; i < totalPoints; ++i)
	{
		idx = i * 3;
		len = std::sqrt(normPtr[idx + 0] * normPtr[idx + 0] + normPtr[idx + 1]
				* normPtr[idx + 1] + normPtr[idx + 2] * normPtr[idx + 2]);
		if (len > 0.0001f)
		{
			normPtr[idx + 0] *= invLen;
			normPtr[idx + 1] *= invLen;
			normPtr[idx + 2] *= invLen;
		}
	}
}

static void	generateIndx(terrain &t)
{
	const int		pointsPerRow = getPointsPerRow(t);
	const int		totalIndices = getIndxCount(t);
	unsigned int	*idxPtr;
	int				index;
	uint32_t		tl;
	uint32_t		tr;
	uint32_t		bl;
	uint32_t		br;

	t.indx.resize(totalIndices);
	idxPtr = t.indx.data();
	index = 0;
	for (int z = 0; z < t.mapSize; ++z)
	{
		for (int x = 0; x < t.mapSize; ++x)
		{
			tl = z * pointsPerRow + x;
			tr = tl + 1;
			bl = tl + pointsPerRow;
			br = bl + 1;
			idxPtr[index++] = tl;
			idxPtr[index++] = tr;
			idxPtr[index++] = bl;
			idxPtr[index++] = tr;
			idxPtr[index++] = br;
			idxPtr[index++] = bl;
		}
	}
}

void	initTerrain(terrain &t, const int &sizeValue)
{
	if (sizeValue <= 0)
		t.mapSize = 1;
	else
		t.mapSize = sizeValue;
	t.terrainType.resize(getMaxIndex(t), land);
	generateHeight(t);
	generateVertices(t);
	generateNormals(t);
	generateIndx(t);
}

void	resetTerrain(terrain &t)
{
	initTerrain(t, 1);
}
