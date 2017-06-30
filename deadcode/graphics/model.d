module deadcode.graphics.model;

import derelict.opengl3.gl3;
import deadcode.graphics.mesh : Mesh;
import deadcode.graphics.material : Mat = Material;
import deadcode.math : Mat4f;
import std.range : front, empty;

final class SubModel
{
	Mesh mesh;
	Mat material;
	bool blend;
	int blendMode = 0;

	@property valid() const
	{
		return material.hasTexture;
	}

	void draw(Mat4f transform)
	{
		//material.shader.setUniform("colMap", 0);

		if (blend)
		{
			glEnable (GL_BLEND);
			//glDisable(GL_DEPTH_TEST);
			glDepthMask(GL_FALSE);
			if (blendMode == 0)
				glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
			else
				glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		}
		else
		{
			glDepthMask(GL_TRUE);
			glDisable (GL_BLEND);
			//glEnable(GL_DEPTH_TEST);
		}

		material.shader.setUniform("MVP", transform);
		material.bind();
		mesh.bind();
		mesh.draw();
		material.unbind();
		glBindVertexArray(0);
		glUseProgram(0);
	}
}

final class Model
{
	SubModel[] subModels;

	SubModel createSubModel()
	{
		auto sm = new SubModel();
		sm.blend = true;
		sm.blendMode = 1;
		subModels ~= sm;
		return sm;
	}

	void ensureSubModelExists()
	{
		if (subModels.empty)
			createSubModel();
	}

	// Mesh of the first SubModel
	@property
	{
		Mesh mesh()
		{
			ensureSubModelExists();
			return subModels.front.mesh;
		}

		void mesh(Mesh m)
		{
			ensureSubModelExists();
			subModels.front.mesh = m;
		}

		Mat material()
		{
			ensureSubModelExists();
			return subModels.front.material;
		}

		void material(Mat m)
		{
			ensureSubModelExists();
			subModels.front.material = m;
		}

		SubModel subModel()
		{
			return subModels.front;
		}

		@property valid() const
		{
			return !subModels.empty && subModels.front.valid;
		}
	}

	void draw(Mat4f transform)
	{
		foreach (m; subModels)
		{
			m.draw(transform);
		}
	}
}


class ModelBuilder
{
    import deadcode.graphics.buffer;
    import deadcode.graphics.material;
    import deadcode.math;

    private
    {
        Model model;
        Mesh activeMesh;
        Mat4f[] transformStack;
    }

    this(Model m = null)
    {
        model = m is null ? new Model() : m;
        resetTransform();
    }

    void resetTransform()
    {
        import std.array;
        transformStack.length = 0;
        assumeSafeAppend(transformStack);
        transformStack ~= Mat4f.IDENTITY;
    }

    void pushMatrix(Mat4f m)
    {
        transformStack ~= transformStack[$-1] * m;
    }

    void setMatrix(Mat4f m)
    {
        transformStack ~= m;
    }

    void pushRotate(float rad, Vec3f axis)
    {
        transformStack ~= transformStack[$-1] * Mat4f.rotate(rad, axis);
    }

    void pushTranslate(Vec3f dist)
    {
        transformStack ~= transformStack[$-1] * Mat4f.makeTranslate(dist);
    }

    void pushScale(Vec3f s)
    {
        transformStack ~= transformStack[$-1] * Mat4f.makeScale(s);
    }
    
    void pushScale(float s)
    {
        pushScale(Vec3f(s,s,s));
    }
    
    void popTransform()
    {
        transformStack.length = transformStack.length - 1;
        assumeSafeAppend(transformStack);
    }

    void setBuiltInMaterial()
    {
        setMaterial(Material.builtIn);
    }

    void setImageMaterial(const(char)[] imagePath)
    {
        setMaterial(Material.create(imagePath));
    }

    void setMaterial(Material m)
    {
        foreach (subModel; model.subModels)
        {
            if (subModel.material is m)
            {
                activeMesh = subModel.mesh;
                return;
            }
        }
        auto sm = model.createSubModel();
        sm.material = m;
        sm.mesh = Mesh.create();
        activeMesh = sm.mesh;
        activeMesh.setBuffer(Buffer.create(), 3, 0);
        activeMesh.setBuffer(Buffer.create(), 2, 1);
        activeMesh.setBuffer(Buffer.create(), 3, 2);
    }

    void addTriangle(float sideLength = 1.0f)
    {
        float d = sideLength * 0.5f;
        addTriangles([Vec2f(-d, -d), Vec2f(d, d), Vec2f(-d, d)]);
    }

    void addTriangles(Vec2f[] pos)
    {
        Vec2f[] _uvs = [ Vec2f(0.0f, 0.0f),
                        Vec2f(1.0f, 1.0f),
                        Vec2f(0.0f, 1.0f) ];

        addTriangles(pos, _uvs);
    }

    void addTriangles(Vec2f[] pos, Vec2f[] _uvs)
    {
        auto i = Vec3f(1.0,1.0,1.0);
        auto cols = [ i, i, i ];
        addTriangles(pos, _uvs, cols);
    }

    void addTriangles(Vec2f[] pos, Vec2f[] _uvs, Vec3f[] cols)
    {
        ensureActiveMesh();

        auto b = activeMesh.buffers[0];
        
        Mat4f trx = transformStack[$-1];
        
        foreach (p; pos)
        {
            auto _pp = Vec4f(p.x, p.y, 0f, 1f);
            auto _p = trx * _pp;
            b.data ~= _p.v[0..3];
        }

        b = activeMesh.buffers[1];
        foreach (u; _uvs)
            b.data ~= u.v;

        b = activeMesh.buffers[2];
        foreach (c; cols)
            b.data ~= c.v;
    }

    void addQuad(float width = 1f, float height = 1f, Vec2f uvScale = Vec2f(1,1))
    {
        float dx = width * 0.5f;
        float dy = height * 0.5f;
        Vec2f[] _uvs1 = [ Vec2f(0.0f, 0.0f),
                         uvScale,
                         Vec2f(0.0f, uvScale.y) ];
        addTriangles([Vec2f(-dx, -dy), Vec2f(dx, dy), Vec2f(-dx, dy)], _uvs1);

        Vec2f[] _uvs2 = [ Vec2f(0.0f, 0.0f),
                          uvScale,
                          Vec2f(uvScale.x, 0.0f) ];

        addTriangles([Vec2f(-dx, -dy), Vec2f(dx, dy), Vec2f(dx, -dy)], _uvs2);
    }

    void addQuad(float d = 1.00f, Vec2f uvScale = Vec2f(1,1))
    {
        addQuad(d, d, uvScale);
    }

    void addTrail(Vec2f[] points, float width = 0.1)
    {
        if (points.length < 2)
            return;

        Vec2f[4] lastQuad;

        foreach (i; 2..points.length)
        {
            //setMatrix(Mat4f.lookAt(
            //    Vec3f(points[i-1], 0f), 
            //    Vec3f(points[i], 0f),
            //    Vec3f(0,0,1)));
            auto p0 = Vec3f(0,1,0);
            auto p1 = Vec3f(points[i-1], 0f);
            auto p2 = Vec3f(points[i], 0f);
            
            // to scale uvs
            auto dist = p1.distanceTo(p2);
            auto uvDelta = dist / width;
            
            pushTranslate(p1);
            //pushRotate(0.1, Vec3f(0,0,1));
            //auto rad = dot(p1 - p2, p0);
            //import std.stdio;
            //writeln(p1 - p2, p0, " ", rad);
            //pushRotate(rad, Vec3f(0,0,1));
            //auto rot = Mat4f.lookAt(Vec3f(0,0,0), p2 - p1, Vec3f(0,0, 1));
            
            //auto rot = Mat4f.lookAt(p1, p2, Vec3f(0, 0, 1));
            
            //pushMatrix(rot);
            
            auto delta = p2 - p1;
            auto a = angleBetween(p0, delta);
            auto side = cross(p0, delta);
            
            pushRotate(side.z < 0 ? -a : a, Vec3f(0,0,1));
            
            auto halfWidth = width * 0.5f;

            pushTranslate(Vec3f(0f, dist * 0.5f, 0f));

            //import std.stdio; writeln(p1, p2, rot.v, transformStack[$-1].v);

            addQuad(width, dist - width, Vec2f(1.0f, uvDelta));

            // Adjust end of last quad and start of this quad


            popTransform();
            popTransform();
            popTransform();
        }
    }

    Model build()
    {
        return model;
    }

    private void ensureActiveMesh()
    {
        if (activeMesh is null)
            setBuiltInMaterial();
    }
}

version (RenderTest)
{
    import deadcode.graphics.renderwindow;
    RenderWindow win;
    import deadcode.math;

    void showtime(Model m, int frameCount = 120, bool animate = true)
    {
        auto trx = Mat4f.IDENTITY;

        foreach (i; 0..120)
        {
            win.render(false);        
            m.draw(trx);
            if (animate)
                trx = trx * Mat4f.rotateY(0.05);
            win.swapBuffers();
        }
    }

    unittest
    {
        win = new RenderWindow("RenderTest", 800, 800);
        win.visible = true;

        foreach (i; 4..5)
        {
            auto builder = new ModelBuilder();
            //auto t = [
            //    Vec2f(-0.80, -0.80), 
            //    Vec2f(-0.60, -0.40), 
            //    Vec2f(-0.50, -0.20), 
            //    Vec2f(0.10, 0.80),
            //    Vec2f(0.00, 0.85),
            //    Vec2f(-0.20, 0.90)
            //];

            auto t = [
                Vec2f(0.0, 0.0), 
                Vec2f(0.5, 0.5), 
                Vec2f(-1, 1), 
                Vec2f(-1, -1), 
                Vec2f(0, -0.5), 
                Vec2f(0.5, 0), 
                Vec2f(1, 1), 
                //Vec2f(-1.0, -1.0), 
                //Vec2f(-0.0, -1.0), 
                //Vec2f(1.0, 1.0), 
                //Vec2f(2.0, 2.0) 
            ];

            if (i == 4)
                builder.setImageMaterial("resources/deadcode-icon.png");
            builder.pushScale(1.0);
            builder.addTrail(t, 0.075);
            auto m = builder.build();
            showtime(m, 120, false);
        }
        import std.stdio;
        readln();
        return;
        version(none)
        foreach (i; 4..5)
        {
            auto builder = new ModelBuilder();
            builder.pushRotate(0.1, Vec3f(0,0,1));
            if (i == 4)
                builder.setImageMaterial("resources/deadcode-icon.png");
            float d = (i * 20) / 100.0f;
            builder.addQuad(d);
            auto m = builder.build();
            showtime(m, 15);
        }
    }
}
