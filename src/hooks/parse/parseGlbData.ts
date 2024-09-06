import * as Cesium from 'cesium'
import {Document, WebIO} from '@gltf-transform/core';

interface ParseGlbDataArgs {
  url: string
  // viewer: Cesium.Viewer
}

export default class ParseGlbData {

  private viewer: Cesium.Viewer

  private IO: WebIO

  private document: Document

  constructor({
    url,
  }: ParseGlbDataArgs) {

    if (!url) throw new Error('url is not exist')

    const io = new WebIO({credentials: 'include'});
    this.IO = io

    this.initDocument(url)
  }

  private async initDocument(url: string) {
    const document = await this.IO.read(url); // 加载 glb 文件
    this.document = document


    const root = document.getRoot();
    const nodes = root.listNodes();
    const meshes = root.listMeshes()
    const accessors = root.listAccessors()
    const primitives = [...meshes.map(mesh => mesh.listPrimitives())]
    const attributes = primitives.map(primitive => primitive[0].listAttributes()).map(attributes => attributes[0].)

    const accessorsData = accessors.map(accessor => accessor.getArray())
    const materials = root.listMaterials();
    const buffers = root.listBuffers();
    const bufferParents = buffers[0].listParents();
    console.log('document: ', {nodes, meshes,
      accessors,
      materials,
      buffers, primitives, attributes, accessorsData});
  }
}