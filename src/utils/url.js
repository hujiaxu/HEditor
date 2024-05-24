import axios from "axios";
export const getIcon = (name, type = 'png', folder = 'tex') => {
    return new URL(`../assets/${folder}/${name}.${type}`, import.meta.url).href;
};
export const getSvgContent = async (url) => {
    return await axios.get(url);
};
export const getTilesetUrl = async (id) => {
    return new URL(`../../public/${id}/3dtiles.json`, import.meta.url).href;
};
//# sourceMappingURL=url.js.map