interface vertexObject {
  x: number;
  y: number;
  z: number;
  vertexIndex: number
}

interface projectedVerticesObject {
  x: number;
  y: number;
  vertex: vertexObject
}

const epsilon = 1e-6;

function isEqual(a, b) {
  return Math.abs(a - b) < epsilon;
}


function computeFaceNormal(v0, v1, v2) {
  const u = {
    x: v1.x - v0.x,
    y: v1.y - v0.y,
    z: v1.z - v0.z,
  };
  const v = {
    x: v2.x - v0.x,
    y: v2.y - v0.y,
    z: v2.z - v0.z,
  };
  const normal = {
    x: u.y * v.z - u.z * v.y,
    y: u.z * v.x - u.x * v.z,
    z: u.x * v.y - u.y * v.x,
  };

  const length = Math.sqrt(normal.x ** 2 + normal.y ** 2 + normal.z ** 2);
  normal.x /= length;
  normal.y /= length;
  normal.z /= length;
  return normal;
}

function getTopFace(vertices: vertexObject[], indices, faceVertexCount) {
  let topFace: vertexObject[] | null = null;
  let maxNormalZ = -Infinity;

  for (let i = 0; i < indices.length; i += faceVertexCount) {
    const faceIndices = indices.slice(i, i + faceVertexCount);
    const faceVertices = faceIndices.map(index => vertices[index]);

    const normal = computeFaceNormal(faceVertices[0], faceVertices[1], faceVertices[2]);

    if (normal.z > maxNormalZ) {
      maxNormalZ = normal.z;
      topFace = faceVertices;
    }
  }

  return topFace;
}

export const computeST = (vertices: number[], indices: number[]) => {

  const vertexCount = vertices.length / 3;
  const faceVertexCount = indices.length / 6;
  const result = new Array(vertexCount * 2).fill(0);
  const verticesObject = new Array(vertexCount).fill(1).map((_, index) => ({
    x: vertices[index * 3],
    y: vertices[index * 3 + 1],
    z: vertices[index * 3 + 2],
    vertexIndex: index
  }))
  const topFace = getTopFace(verticesObject, indices, faceVertexCount);
  if (topFace) {
    const edge1 = {
      x: topFace[1].x - topFace[0].x,
      y: topFace[1].y - topFace[0].y,
      z: topFace[1].z - topFace[0].z,
    };
    const lengthEdge1 = Math.sqrt(edge1.x ** 2 + edge1.y ** 2 + edge1.z ** 2);
    const localX = {
      x: edge1.x / lengthEdge1,
      y: edge1.y / lengthEdge1,
      z: edge1.z / lengthEdge1,
    };

    const normal = computeFaceNormal(topFace[0], topFace[1], topFace[2]);

    const localY = {
      x: normal.y * localX.z - normal.z * localX.y,
      y: normal.z * localX.x - normal.x * localX.z,
      z: normal.x * localX.y - normal.y * localX.x,
    };

    const lengthLocalY = Math.sqrt(localY.x ** 2 + localY.y ** 2 + localY.z ** 2);
    localY.x /= lengthLocalY;
    localY.y /= lengthLocalY;
    localY.z /= lengthLocalY;

    const projectedVertices: projectedVerticesObject[] = [];

    for (const vertex of topFace) {
      const relativePos = {
        x: vertex.x - topFace[0].x,
        y: vertex.y - topFace[0].y,
        z: vertex.z - topFace[0].z,
      };

      const x = relativePos.x * localX.x + relativePos.y * localX.y + relativePos.z * localX.z;
      const y = relativePos.x * localY.x + relativePos.y * localY.y + relativePos.z * localY.z;

      projectedVertices.push({ x: x, y: y, vertex: vertex });
    }

    let minX = Infinity, maxX = -Infinity;
    let minY = Infinity, maxY = -Infinity;

    for (const p of projectedVertices) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    for (const p of projectedVertices) {
      const isLeft = isEqual(p.x, minX);
      const isRight = isEqual(p.x, maxX);
      const isBottom = isEqual(p.y, minY);
      const isTop = isEqual(p.y, maxY);

      if (isLeft && isTop) {
        result[p.vertex.vertexIndex * 2] = 0.0;
        result[p.vertex.vertexIndex * 2 + 1] = 1.0;
      } else if (isLeft && isBottom) {
        result[p.vertex.vertexIndex * 2] = 0.0;
        result[p.vertex.vertexIndex * 2 + 1] = 0.0;
      } else if (isRight && isTop) {
        result[p.vertex.vertexIndex * 2] = 1.0;
        result[p.vertex.vertexIndex * 2 + 1] = 1.0;
      } else if (isRight && isBottom) {
        result[p.vertex.vertexIndex * 2] = 1.0;
        result[p.vertex.vertexIndex * 2 + 1] = 0.0;
      }
    }

  }

  return result;
}
