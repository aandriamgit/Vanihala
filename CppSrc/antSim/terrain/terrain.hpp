#pragma once

#include <cstdint>
#include <vector>

enum type : uint8_t
{
	water,
	land
};

struct		terrain
{
	int		mapSize;
	std::vector<type> terrainType;
	std::vector<float> height;
	std::vector<float> vertices;
	std::vector<float> normals;
	std::vector<uint32_t> indx;
};

const int	getIndex(const int &maxValue, const int &x, const int &y);
const int	getX(const int &maxValue, const int &index);
const int	getY(const int &maxValue, const int &index);
const int	getMaxIndex(const terrain &t);
const int	getVertMaxIndex(const terrain &t);
const int	getIndxCount(const terrain &t);
const int	getPointsPerRow(const terrain &t);
