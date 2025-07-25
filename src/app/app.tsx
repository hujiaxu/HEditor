import HEditor from '../components/editor/HEditor'
// import CesiumBuildingTexture from "examples/CesiumBuildingTexture";
// import CesiumBuildingTexture from "/@/examples/CesiumGltfTexture";
import React from "react";
import BaseMap from "../components/common/BaseMap";
import BaseMapWith3dtiles from "../components/common/BaseMapWith3dtiles";

function App() {
  return (
    <main>
      <BaseMapWith3dtiles></BaseMapWith3dtiles>
      {/* <BaseMap></BaseMap> */}
      {/* <HEditor></HEditor> */}
    </main>
  );
}

export default App;
