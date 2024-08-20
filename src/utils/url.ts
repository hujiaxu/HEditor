import axios from "axios";

export const getIcon = (name: string, type = "png", folder = "tex") => {
  return new URL(`../assets/${folder}/${name}.${type}`, import.meta.url).href;
};

export const getSvgContent = async (url: string) => {
  return await axios.get(url);
};

export const getTilesetUrl = async (id: string) => {
  return new URL(`../../public/${id}/3dtiles.json`, import.meta.url).href;
};

export const getModelUrl = async (name: string) => {
  return new URL(`../../public/models/${name}/${name}.glb`, import.meta.url).href;
}
